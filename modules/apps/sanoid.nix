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

  cfg = config.custom.apps.sanoid;

in {

  options.custom.apps.sanoid = {
    snapshottedDatasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "ZFS datasets to snapshot via Sanoid (15-minute, hourly, daily, weekly, monthly).";
    };
  };

  config = lib.mkIf (builtins.length cfg.snapshottedDatasets > 0) {
    services.sanoid = {
      enable = true;
      package = pkgs.unstable.sanoid;
      interval = "*-*-* *:00/15:00";
      datasets = lib.genAttrs cfg.snapshottedDatasets (dataset: {
        frequent = 16;
        hourly = 24;
        daily = 7;
        weekly = 4;
        monthly = 12;
        yearly = 0;
        autosnap = true;
        autoprune = true;
      });
    };
  };

}

