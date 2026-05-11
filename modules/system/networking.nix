{ config, lib, ... }:

let

  cfg = config.custom.system.networking;

in {

  options.custom.system.networking = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable custom networking configuration";
    };
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "nixos";
      description = "The assigned hostname for the machine";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = cfg.hostName;
  };

}

