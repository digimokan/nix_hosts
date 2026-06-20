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

  cfg = config.custom.system.linuxFirmware;

in {

  options.custom.system.linuxFirmware = {
    installPolicy = lib.mkOption {
      type = lib.types.enum [
        # just use built-in open-source firmwares already present in Linux kernel
        "kernel-builtins"
        # install standard 'linux-firmware' package (redistributable proprietary blobs)
        "builtins-and-proprietary"
        # builtins-and-proprietary PLUS install specific unfree/restricted-license blobs
        "builtins-and-proprietary-with-restricted-licenses"
      ];
      default = "kernel-builtins";
      description = "Global policy for installing hardware firmware blobs (graphics, networking, audio, bluetooth, etc).";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.installPolicy == "builtins-and-proprietary") {
      hardware.enableRedistributableFirmware = true;
    })

    (lib.mkIf (cfg.installPolicy == "builtins-and-proprietary-with-restricted-licenses") {
      hardware.enableAllFirmware = true;
    })
  ];

}

