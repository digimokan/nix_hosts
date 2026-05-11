{ config, lib, ... }:

let

  cfg = config.custom.users.root;

in {

  options.custom.users.root = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable and configure the root user account";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.root = {
      isNormalUser = false;
      # TODO: put password path here
    };
  };

}

