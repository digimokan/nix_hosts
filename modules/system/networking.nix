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
  };

  config = {
    networking.networkmanager.enable = cfg.useNetworkManager;
    networking.nameservers = lib.mkIf (cfg.primaryDnsServerIpAddr != null) [ cfg.primaryDnsServerIpAddr ];

    networking.hostId = lib.mkDefault (
      builtins.substring 0 8 (builtins.hashString "sha256" config.networking.hostName)
    );
  };

}

