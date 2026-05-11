{ config, lib, ... }:

let

  cfg = config.custom.users.root;

in {

  options.custom.users.root = {
    enable = lib.mkEnableOption "the root user account";
  };

  config = lib.mkIf cfg.enable {
    users.users.root = {
      isNormalUser = false;
      # TODO: sops
    };
  };

}

