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
    sops.secrets.server_host_root_password = {
      sopsFile = ../../secrets/server_host_secrets.yaml;
      neededForUsers = true;
    };

    users.users.root = {
      isNormalUser = false;
      hashedPasswordFile = config.sops.secrets.server_host_root_password.path;
    };
  };

}

