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

  cfg = config.custom.system.networking;

in {

  options.custom.system.networking = {
    useNetworkManager = lib.mkEnableOption "Whether to use NetworkManager (typically true for desktops, false for servers).";

    primaryDnsServerIpAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The IP address of the primary DNS server. If set, this forces the system to use it.";
    };

    trustedIpLinkInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Network interfaces that bypass the firewall (fully trusted).";
    };

    netMgrGroup = lib.mkOption {
      type = lib.types.str;
      description = "The NetworkManager group name. Only exported if NetworkManager is enabled.";
    };

    persistConfigDir = lib.mkOption {
      type = lib.types.str;
      description = "The directory containing state to persist. Only exported if NetworkManager is enabled.";
    };
  };

  config = lib.mkMerge [
    {
      networking.networkmanager.enable = cfg.useNetworkManager;
      networking.nameservers = lib.mkIf (cfg.primaryDnsServerIpAddr != null) [ cfg.primaryDnsServerIpAddr ];
      networking.hostId = lib.mkDefault (
        builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName)
      );
      networking.firewall.trustedInterfaces = cfg.trustedIpLinkInterfaces;
    }

    (lib.mkIf cfg.useNetworkManager {
      custom.system.networking.netMgrGroup = "networkmanager";
      custom.system.networking.persistConfigDir = "/etc/NetworkManager";
    })
  ];

}

