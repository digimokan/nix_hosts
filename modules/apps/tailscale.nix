/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    imports: A list of other files or modules to include
    options: merged tree of all option _declarations_ across the system
    config: final, merged config tree of entire system, shared among modules
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

let

  cfg = config.custom.apps.tailscale;

in {

  options.custom.apps.tailscale = {
    enable = lib.mkEnableOption "Enable Tailscale client and daemon.";

    enableSshServer = lib.mkEnableOption "Enable Tailscale SSH server (--ssh).";

    enableShieldsUp = lib.mkEnableOption "Block incoming LAN connections (--shields-up).";

    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether Tailscale should accept DNS configuration (MagicDNS and
        global nameservers) from the tailnet and manage /etc/resolv.conf.
        Set to false on routers running a local DNS resolver (Unbound) so
        tailscaled does not overwrite /etc/resolv.conf with 100.100.100.100.
        When false, other tailnet hosts can still resolve this host by its
        MagicDNS name, but this host cannot resolve other tailnet hostnames.
      '';
    };

    authKeyPath = lib.mkOption {
      type = lib.types.str;
      description = "Auth key to authenticate and join the tailnet.";
    };

    ipLinkInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "tailscale0" ];
      description = "The virtual network interfaces created by Tailscale.";
    };

    udpPort = lib.mkOption {
      type = lib.types.port;
      readOnly = true;
      description = ''
        Read-only export of the UDP port Tailscale listens on for direct
        WireGuard peer-to-peer tunnels (tracks NixOS's services.tailscale.port,
        default 41641).
      '';
    };

    defaultTailnetCidr = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        Read-only export of the default carrier-grade NAT CIDR IP address block
        used by Tailscale (100.64.0.0/10).
      '';
    };
  };

  config = lib.mkMerge [
    {
      custom.apps.tailscale.udpPort = config.services.tailscale.port;
      custom.apps.tailscale.defaultTailnetCidr = "100.64.0.0/10";
    }

    (lib.mkIf cfg.enable {
      services.tailscale = {
        enable = true;
        authKeyFile = cfg.authKeyPath;
        extraUpFlags =
          (lib.optional cfg.enableSshServer "--ssh")
          ++ (lib.optional cfg.enableShieldsUp "--shields-up")
          ++ [ "--accept-dns=${lib.boolToString cfg.acceptDns}" ];
      };

      assertions = [
        {
          assertion = !(cfg.enableSshServer && cfg.enableShieldsUp);
          message = (
            "The options custom.apps.tailscale.enableSshServer and "
            + "custom.apps.tailscale.enableShieldsUp are mutually exclusive "
            + "and cannot be enabled at the same time."
          );
        }
      ];
    })
  ];

}

