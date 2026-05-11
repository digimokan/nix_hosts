{ config, lib, ... }:

let

  cfg = config.custom.system.boot;

in {

  options.custom.system.boot = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable standard EFI systemd-boot";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };

}

