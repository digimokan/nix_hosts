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

  cfg = config.custom.system.videoChipset;
  firmwareCfg = config.custom.system.linuxFirmware;

in {

  options.custom.system.videoChipset = lib.mkOption {
    type = lib.types.enum [
      "disabled"
      "amdgpu"
      "intel"
    ];
    default = "disabled";
    description = ''
      The GPU driver backend.
      'disabled' uses the basic EFI framebuffer (i.e. for servers).
    '';
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = (cfg == "amdgpu" || cfg == "intel") ->
            (firmwareCfg.installPolicy == "builtins-and-proprietary" ||
            firmwareCfg.installPolicy == "builtins-and-proprietary-with-restricted-licenses");
          message = (
            "Video chipset '${cfg}' requires proprietary firmware. "
            + "Set custom.system.linuxFirmware.installPolicy to "
            + "'builtins-and-proprietary' or 'builtins-and-proprietary-with-restricted-licenses'."
          );
        }
      ];
    }

    (lib.mkIf (cfg == "disabled") {
      boot.kernelParams = [ "nomodeset" ];
      boot.extraModprobeConfig = ''
        install amdgpu ${pkgs.coreutils}/bin/true
        install i915 ${pkgs.coreutils}/bin/true
        install nouveau ${pkgs.coreutils}/bin/true
      '';
    })

    (lib.mkIf (cfg == "amdgpu") {
      # Load the AMD graphics kernel module early in the boot process
      boot.initrd.kernelModules = [ "amdgpu" ];
      # Enable Mesa user-space drivers (OpenGL/Vulkan) and VA-API video acceleration
      hardware.graphics.enable = true;
    })

    (lib.mkIf (cfg == "intel") {
      # Load the Intel graphics kernel module early in the boot process
      boot.initrd.kernelModules = [ "i915" ];
      # Enable Mesa user-space drivers
      hardware.graphics.enable = true;
      # Enable Intel media driver for Broadwell+ VA-API video acceleration
      hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];
    })
  ];

}

