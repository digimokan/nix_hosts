/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    imports: A list of other files or modules to include
    options: merged tree of all option _declarations_ across the system
    config: final, merged config tree of entire system, shared among modules
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

let

  cfg = config.custom.infrastructure.bootloader;

in {

  options.custom.infrastructure.bootloader = lib.mkOption {
    type = lib.types.enum [ "none" "grub" "systemd-boot-efi" ];
    default = "none";
    description = "The active bootloader for the system (set automatically by bootloader modules).";
  };

  config = {
    assertions = [
      {
        assertion = cfg != "none";
        message = "A bootloader must be explicitly enabled (e.g., "
          + "custom.system.grub.mode or custom.system.systemdBootEfi.enable).";
      }
    ];
  };
}

