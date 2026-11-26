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

  cfg = config.custom.system.unboundDnsResolver;

in {

  options.custom.system.unboundDnsResolver = {
    enable = lib.mkEnableOption "Unbound Local DNS Resolver";

    enableIpv6 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable IPv6 support in Unbound (requires
        custom.system.networking.enableIpv6 = true).
        When true, this enables:
        - Upstream recursive DNS queries over IPv6 (do-ip6 = "yes").
        - Default-deny IPv6 access-control (::/0 refuse) with IPv6 loopback
          (::1/128 allow) permitted.
        Note: To accept inbound IPv6 client queries, also include "::" (or an
        explicit IPv6 address) in listenIpAddrs and IPv6 CIDRs in
        allowedClientCidrs.
      '';
    };

    listenIpAddrs = lib.mkOption {
      type = lib.types.nonEmptyListOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = ''
        Local IP addresses Unbound listens on for incoming client queries.
        Defaults to IPv4 loopback only ("127.0.0.1") so WAN interfaces are
        never exposed unintentionally. On routers, set this explicitly to
        loopback plus your LAN/VLAN gateway IPs (e.g., [ "127.0.0.1"
        "192.168.10.1" "192.168.20.1" ]).
      '';
    };

    allowedClientCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Client IPv4 CIDR blocks permitted to query this resolver in addition
        to loopback (127.0.0.0/8). All other source IPs are refused.
        e.g., [ "192.168.10.0/24" "192.168.20.0/24" ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.unbound = {
      enable = true;
      # Disable NixOS's implicit local DNS hook (which injects ::1) so local
      # queries use the IPv4 resolver configured explicitly in networking.nix.
      resolveLocalQueries = false;
      settings.server = {
        interface = cfg.listenIpAddrs;
        # Allow binding static IPs that are not yet assigned on boot (avoids
        # startup races with VLAN interface bring-up; Linux IP_FREEBIND).
        ip-freebind = "yes";
        do-ip6 = if cfg.enableIpv6 then "yes" else "no";
        # Refuse queries by default; allow loopback and declared LAN CIDRs only.
        access-control =
          [
            "0.0.0.0/0 refuse"
            "127.0.0.0/8 allow"
          ]
          ++ lib.optionals cfg.enableIpv6 [
            "::/0 refuse"
            "::1/128 allow"
          ]
          ++ builtins.map (cidr: "${cidr} allow") cfg.allowedClientCidrs;
        hide-identity = "yes";
        hide-version = "yes";
        # Ignore out-of-bailiwick glue records to prevent cache poisoning.
        harden-glue = "yes";
        # Require DNSSEC data for trust-anchored zones; reject stripped replies.
        harden-dnssec-stripped = "yes";
        # DNS rebinding protection: strip private IPs (RFC 1918, link-local,
        # CGNAT, and IPv6 ULA/link-local) from external DNS responses.
        private-address = [
          "10.0.0.0/8"
          "172.16.0.0/12"
          "192.168.0.0/16"
          "169.254.0.0/16"
          "100.64.0.0/10"
          "fd00::/8"
          "fe80::/10"
        ];
      };
    };

    assertions = [
      {
        assertion = cfg.enableIpv6 ->
          config.custom.system.networking.enableIpv6;
        message = (
          "custom.system.unboundDnsResolver.enableIpv6 requires "
          + "custom.system.networking.enableIpv6 to be enabled."
        );
      }
    ];
  };

}

