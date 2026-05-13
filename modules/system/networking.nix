{ config, lib, ... }:

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
  };

  config = {
    networking.hostName = cfg.hostName;
    networking.hostId = cfg.hostId;
  };

}

