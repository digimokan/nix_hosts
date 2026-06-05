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
      description = "List of extra ZFS pools to import, and their specific datasets to mount via systemd.";
      default = [];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          poolName = lib.mkOption {
            type = lib.types.str;
            description = "The root name of the zpool (e.g., 'zdata_tm1'). The root dataset will remain unmounted.";
          };
          baseDataset = lib.mkOption {
            type = lib.types.str;
            description = "The name of the primary child dataset (e.g., 'data' or 'home').";
          };
          baseMountPoint = lib.mkOption {
            type = lib.types.str;
            description = "The absolute path where the baseDataset is mounted (e.g., '/data' or '/home').";
          };
          childDatasets = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of child directories to create as dedicated ZFS datasets under the baseDataset (e.g., [ 'testuser1' ]).";
          };
        };
      });
    };
  };

  config = lib.mkMerge [
    {
      # Forces import of zroot on boot. Strongly not recommended by NixOS.
      boot.zfs.forceImportRoot = false;
      # Extra pools to import on boot, along with main zroot pool.
      boot.zfs.extraPools = builtins.map (p: p.poolName) cfg.storagePools;

      # Datasets in each extra pool.
      fileSystems = lib.mkMerge (builtins.map (pool:
        let
          # The base mount (e.g., zdata_tm1/home -> /home).
          baseMount = lib.nameValuePair pool.baseMountPoint {
            device = "${pool.poolName}/${pool.baseDataset}";
            fsType = "zfs";
            options = [ "zfsutil" ];
          };

          # The child mounts (e.g., zdata_tm1/home/testuser1 -> /home/testuser1)
          childMounts = builtins.listToAttrs (builtins.map (child:
            lib.nameValuePair "${pool.baseMountPoint}/${child}" {
              device = "${pool.poolName}/${pool.baseDataset}/${child}";
              fsType = "zfs";
              options = [ "zfsutil" ];
            }
          ) pool.childDatasets);
        in
          { "${baseMount.name}" = baseMount.value; } // childMounts
      ) cfg.storagePools);
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

