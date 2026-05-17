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

  cfg = config.custom.system.cpuMicrocode;

in {

  options.custom.system.cpuMicrocode = lib.mkOption {
    type = lib.types.enum [ "none" "amd" "intel" ];
    default = "none";
    description = "The CPU vendor for applying early microcode updates.";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg == "amd") {
      hardware.cpu.amd.updateMicrocode = true;
      hardware.cpu.amd.microcodePackage = pkgs.unstable.microcodeAmd;
    })
    (lib.mkIf (cfg == "intel") {
      hardware.cpu.intel.updateMicrocode = true;
      hardware.cpu.intel.microcodePackage = pkgs.unstable.microcodeIntel;
    })
  ];

}

