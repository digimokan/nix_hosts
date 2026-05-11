{ config, lib, ... }:

let

  cfg = config.custom.system.networking;

in {

  options.custom.system.networking = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable networking and hostname management";
    };

    hostName = lib.mkOption {
      type = lib.types.str;
      description = "REQUIRED: The assigned hostname for the machine";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = cfg.hostName;
  };

}

