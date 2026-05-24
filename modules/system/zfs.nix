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

  cfg = config.custom.system.zfs;

in {

  options.custom.system.zfs = {
    dailyAutoScrubHour = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The hour (e.g., '03') to perform a daily ZFS scrub. If not set, autoscrub is disabled.";
    };

    randomizedScrubDelayDuration = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = "Randomized time span (e.g., '0', '6h', '30m', '30s') to delay the scrub.";
    };

    storagePools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of additional ZFS pools to import automatically on boot.";
    };
  };

  config = lib.mkMerge [
    {
      # Forces import of zroot on boot. Strongly not recommended by NixOS.
      boot.zfs.forceImportRoot = false;
      # Extra pools to import on boot, along with main zroot pool.
      boot.zfs.extraPools = cfg.storagePools;
    }

    (lib.mkIf (cfg.dailyAutoScrubHour != null) {
      services.zfs.autoScrub = {
        enable = true;
        interval = "*-*-* ${cfg.dailyAutoScrubHour}:00:00";
        randomizedDelaySec = cfg.randomizedScrubDelayDuration;
      };
    })
  ];

}

