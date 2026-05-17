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

/**
  === ESSENTIAL COMMANDS ===
  List Snaps       : zfs list -t snapshot
  List Snaps (Var) : zfs list -t snapshot -r <dataset_name>
  View Snap Size   : zfs list -t snapshot -o name,used,creation
  Browse Snap Files: cd <dataset_path>/.zfs/snapshot
  Restore File     : sudo cp <dataset_path>/.zfs/snapshot/<snap_name>/<file> /tmp/
  Rollback (DANGER): sudo zfs rollback -r <dataset_name>@<snapshot_name>
*/

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
        frequently = 16;
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

