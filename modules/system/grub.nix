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

in {

  options.custom.system.grub = {
    enableMode = lib.mkOption {
      type = lib.types.enum [ "none" "efi" "bios" ];
      default = "none";
      description = "Enable GRUB bootloader in specific mode";
    };

    efiModeMirrorTwoDisks = lib.mkEnableOption "Use mirrored EFI partitions mounted at /boot and /boot-fallback.";

    efiModeRemovableDisks = lib.mkEnableOption
      ("Install GRUB to the fallback EFI path (of one disk, or two mirrored disks) "
      + "without modifying NVRAM boot entries "
      + "(CRITICAL for USB enclosures, as ports can re-enumerate).");

    biosModeDevices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description =
        "List of devices to install GRUB to for BIOS mode (e.g., ['/dev/disk/by-id/nvme-eui...']).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enableMode != "none") {
      boot.loader.grub.enable = true;
      custom.infrastructure.bootloader = "grub";
    })

    (lib.mkIf (cfg.enableMode == "efi") {
      boot.loader.grub.efiSupport = true;
      boot.loader.grub.efiInstallAsRemovable = cfg.efiModeRemovableDisks;
      boot.loader.efi.canTouchEfiVariables = !cfg.efiModeRemovableDisks;

      # testing. todo-optionalize this.....
      boot.initrd.availableKernelModules = [ "usb_storage" "uas" ];

      boot.loader.grub.mirroredBoots = lib.mkIf cfg.efiModeMirrorTwoDisks [
        { devices = [ "nodev" ]; path = "/boot"; }
        { devices = [ "nodev" ]; path = "/boot-fallback"; }
      ];

      boot.loader.grub.devices = lib.mkIf (!cfg.efiModeMirrorTwoDisks) [ "nodev" ];
    })

    (lib.mkIf (cfg.enableMode == "bios") {
      boot.loader.grub.devices = cfg.biosModeDevices;
    })
  ];

}

