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
  infra = config.custom.infrastructure.lan;

in {

  options.custom.system.networking = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "The hostname of the machine.";
    };

    hostId = lib.mkOption {
      type = lib.types.str;
      # To generate a deterministic hostId based on the hostname, run:
      #   echo "<hostname>" | md5sum | cut -c1-8
      description = "The 8-character ZFS hostId.";
    };

    useNetworkManager = lib.mkEnableOption "Whether to use NetworkManager (typically true for desktops, false for servers).";

    forceRouterDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Force the system to use the global router IP for DNS.";
    };
  };

  config = {
    networking.hostName = cfg.hostName;
    networking.hostId = cfg.hostId;
    networking.networkmanager.enable = cfg.useNetworkManager;

    networking.nameservers = lib.mkIf cfg.forceRouterDns [ infra.routerIp ];

    assertions = [
      {
        assertion = (builtins.stringLength cfg.hostId) == 8;
        message = (
          "The custom.system.networking.hostId option must be exactly 8 "
          + "characters long. Length provided: "
          + "${builtins.toString (builtins.stringLength cfg.hostId)} "
          + "characters ('${cfg.hostId}')."
        );
      }

      (let
        isValidHex = str: (lib.strings.match "^[0-9a-f]+$" str) != null;
      in {
        assertion = isValidHex cfg.hostId;
        message = (
          "The custom.system.networking.hostId option must consist ONLY "
          + "of lowercase hexadecimal letters (a-f) and numbers (0-9). "
          + "Value provided: '${cfg.hostId}'"
        );
      })
    ];
  };

}

