{ config, lib, pkgs, options, ... }:

let

  cfg = config.custom.users.root;

in {

  options.custom.users.root = {
    enable = lib.mkEnableOption "Enable and configure the root user account";
  };

  config = lib.mkIf cfg.enable {
    users.users.root = {
      isNormalUser = false;
      hashedPasswordFile = config.sops.secrets.server_host_root_password.path;
    };
  };

}

