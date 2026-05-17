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
    hourlySnapshotDatasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "ZFS datasets to snapshot hourly (keep 24h, 7d, 4w, 12m).";
    };

    fifteenMinutelySnapshotDatasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "ZFS datasets to snapshot every 15 mins (keep 16 frequent, 24h, 7d, 4w, 12m).";
    };
  };

  config = lib.mkIf (
    builtins.length cfg.hourlySnapshotDatasets > 0 ||
    builtins.length cfg.fifteenMinutelySnapshotDatasets > 0
  ) {
    services.sanoid = {
      enable = true;
      package = pkgs.unstable.sanoid;
      datasets = lib.mkMerge [
        (lib.genAttrs cfg.hourlySnapshotDatasets (dataset: {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 0;
          autosnap = true;
          autoprune = true;
        }))

        (lib.genAttrs cfg.fifteenMinutelySnapshotDatasets (dataset: {
          frequent = 16; # Keep 4 hours worth of 15-minute snapshots
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 0;
          autosnap = true;
          autoprune = true;
        }))
      ];
    };
  };

}

