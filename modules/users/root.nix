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
    sops.secrets.root_password = {
      neededForUsers = true;
    };

    users.users.root = {
      isNormalUser = false;
      hashedPasswordFile = config.sops.secrets.root_password.path;
    };
  };

}

