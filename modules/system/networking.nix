{ config, lib, pkgs, options, ... }:

let

  cfg = config.custom.system.networking;

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
  };

  config = {
    networking.hostName = cfg.hostName;
    networking.hostId = cfg.hostId;
    networking.networkmanager.enable = cfg.useNetworkManager;
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

