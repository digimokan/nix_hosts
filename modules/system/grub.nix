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

  cfg = config.custom.system.grub;
  diskoDisks = config.disko.devices.disk;
  isMirror = builtins.length (builtins.attrValues diskoDisks) == 2;

in {

  options.custom.system.grub = {
    enableMode = lib.mkOption {
      type = lib.types.enum [ "efi" "bios" ];
      description = "Enable GRUB bootloader in EFI or BIOS mode.";
    };

    efiModeRemovableDisks = lib.mkEnableOption
      ("Install GRUB to the fallback EFI path (of one disk, or two mirrored disks) "
      + "without modifying NVRAM boot entries "
      + "(CRITICAL for USB enclosures, as ports can re-enumerate).");
  };

  config = {
    boot.loader.grub.enable = true;
  } // lib.mkMerge [
    (lib.mkIf (cfg.enableMode == "efi") {
      boot.loader.grub.efiSupport = true;
      boot.loader.grub.efiInstallAsRemovable = cfg.efiModeRemovableDisks;
      boot.loader.efi.canTouchEfiVariables = !cfg.efiModeRemovableDisks;

      boot.initrd.availableKernelModules = lib.mkIf cfg.efiModeRemovableDisks [
        "usb_storage"
        "uas"
      ];

      boot.loader.grub.mirroredBoots = lib.mkIf isMirror [
        { devices = [ "nodev" ]; path = "/boot"; }
        { devices = [ "nodev" ]; path = "/boot-fallback"; }
      ];

      boot.loader.grub.devices = lib.mkIf (!isMirror) [ "nodev" ];
    })

    (lib.mkIf (cfg.enableMode == "bios") {
      boot.loader.grub.devices = lib.mapAttrsToList (name: disk: disk.device) diskoDisks;
    })
  ];

}

