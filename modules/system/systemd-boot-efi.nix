{ config, lib, pkgs, options, ... }:

let

  cfg = config.custom.system.systemdBootEfi;

in {

  options.custom.system.systemdBootEfi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable systemd-boot with EFI variable modification";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  };

}

