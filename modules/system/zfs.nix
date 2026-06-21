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
  ashiftType = lib.types.ints.between 9 16;
  aclType = lib.types.enum [ "off" "posixacl" "nfsv4" ];
  xattrType = lib.types.enum [ "on" "sa" ];
  atimeType = lib.types.enum [ "on" "off" "relatime" ];
  encMethodType = lib.types.enum [ "none" "passphrase" "keyfile" ];
  onOffType = lib.types.enum [ "on" "off" ];

in {

  options.custom.system.zfs = let
    datasetType = lib.types.submoduleWith {
      modules = [
        ({ config, ... }: {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            mountPoint = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
            compression = lib.mkOption { type = lib.types.str; default = cfg.datasetCompression; };
            recordsize = lib.mkOption { type = lib.types.str; default = cfg.datasetRecordsize; };
            exec = lib.mkOption { type = onOffType; default = cfg.datasetExec; };
            setuid = lib.mkOption { type = onOffType; default = cfg.datasetSetuid; };
            children = lib.mkOption { type = lib.types.listOf datasetType; default = []; };
          };
        })
      ];
    };

    poolSchemaType = lib.types.submodule {
      options = {
        poolName = lib.mkOption { type = lib.types.str; };
        disks = lib.mkOption { type = lib.types.listOf lib.types.str; default = cfg.poolDisks; };
        poolAshift = lib.mkOption { type = ashiftType; default = cfg.poolAshift; };
        poolCompatibility = lib.mkOption { type = lib.types.str; default = cfg.poolCompatibility; };
        rootFsAclType = lib.mkOption { type = aclType; default = cfg.rootFsAclType; };
        rootFsXattr = lib.mkOption { type = xattrType; default = cfg.rootFsXattr; };
        rootFsAtime = lib.mkOption { type = atimeType; default = cfg.rootFsAtime; };
        rootFsEncryptionMethod = lib.mkOption { type = encMethodType; default = cfg.rootFsEncryptionMethod; };
        rootFsEncryptionSopsSecretName = lib.mkOption { type = lib.types.nullOr lib.types.str; default = cfg.rootFsEncryptionSopsSecretName; };
        rootFsEncryptionTempfilePath = lib.mkOption { type = lib.types.str; default = cfg.rootFsEncryptionTempfilePath; };
        rootFsCompression = lib.mkOption { type = lib.types.str; default = cfg.datasetCompression; };
        rootFsRecordsize = lib.mkOption { type = lib.types.str; default = cfg.datasetRecordsize; };
        rootFsExec = lib.mkOption { type = onOffType; default = cfg.datasetExec; };
        rootFsSetuid = lib.mkOption { type = onOffType; default = cfg.datasetSetuid; };
        datasets = lib.mkOption { type = lib.types.listOf datasetType; default = []; };
      };
    };

  in {

    poolDisks = lib.mkOption {
      /**
        To obtain the Disk ID, run 'ls -l /dev/disk/by-id/':
          - SATA SSDs:      use ID prefixed with 'wwn-'
          - USB Enclosures: use ID prefixed with 'wwn-'
          - NVME SSDs:      use ID prefixed with 'nvme-eui.'
          - USB Sticks:     use ID prefixed with 'usb-'
      */
      type = lib.types.listOf lib.types.str;
      description = "Default list of /dev/disk/by-id's to use for the zpool.";
    };
    poolAshift = lib.mkOption {
      type = ashiftType;
      default = 12;
      description = "Default ashift (sector size) for new ZFS pools.";
    };
    poolCompatibility = lib.mkOption {
      /**
        Lock feature set to specific OpenZFS version to suppress upgrade warns.
        This can be updated to zfs version on the latest minimal installer.
        Warning: after updating, reinstalling OS zpools on all hosts should
          be done, else rollbacks may not work.
      */
      type = lib.types.str;
      default = "openzfs-2.2-linux";
      description = "Default OpenZFS compatibility feature set.";
    };

    rootFsAclType = lib.mkOption {
      type = aclType;
      default = "posixacl";
      description = "Default ACL type for the pool's root dataset.";
    };
    rootFsXattr = lib.mkOption {
      type = xattrType;
      default = "sa";
      description = "Default extended attribute type for the root dataset.";
    };
    rootFsAtime = lib.mkOption {
      type = atimeType;
      default = "off";
      description = "Default atime setting for the root dataset.";
    };
    rootFsEncryptionMethod = lib.mkOption {
      type = encMethodType;
      default = "none";
      description = "Encryption method for the root filesystem.";
    };
    rootFsEncryptionSopsSecretName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The explicit SOPS secret name containing the encryption key/passphrase.";
    };
    rootFsEncryptionTempfilePath = lib.mkOption {
      type = lib.types.str;
      default = "/tmp/nix_hosts_zfs_zroot_passphrase";
      description = "Absolute path on target host where orchestrator temporarily stores the ZFS passphrase for Disko.";
    };

    datasetCompression = lib.mkOption {
      type = lib.types.str;
      default = "lz4";
      description = "Compression algorithm. Inherited by children, but can be overridden.";
    };
    datasetRecordsize = lib.mkOption {
      type = lib.types.str;
      default = "128K";
      description = "Default recordsize. Inherited by children, but can be overridden.";
    };
    datasetExec = lib.mkOption {
      type = onOffType;
      default = "on";
      description = "Default exec property (on/off).";
    };
    datasetSetuid = lib.mkOption {
      type = onOffType;
      default = "on";
      description = "Default setuid property (on/off).";
    };

    dailyAutoScrubHour = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The hour (e.g., '03') to perform a daily ZFS scrub of all pools. If not set, autoscrub is disabled.";
    };
    randomizedScrubDelayDuration = lib.mkOption {
      type = lib.types.str;
      default = "0";
      description = "Randomized time span (e.g., '0', '6h', '30m', '30s') to delay the scrub.";
    };

    zrootPoolSchema = lib.mkOption {
      type = poolSchemaType;
      description = "The schema for the OS zroot pool, passed natively to the Disko layout generator.";
    };
    storagePoolSchemas = lib.mkOption {
      description = "List of extra ZFS pools to import and mount via systemd.";
      default = [];
      type = lib.types.listOf poolSchemaType;
    };
  };

  config = lib.mkMerge [
    (import ../../disko/layout-generator.nix { inherit lib; } cfg.zrootPoolSchema)
    {
      boot.zfs.forceImportRoot = false;
      boot.zfs.extraPools = builtins.map (p: p.poolName) cfg.storagePoolSchemas;
      fileSystems = let
        flattenDatasets = parentName: datasets:
          builtins.concatLists (builtins.map (ds:
            let
              fullName = if parentName == "" then ds.name else "${parentName}/${ds.name}";
              current = if ds.mountPoint != null then [
                { inherit fullName; inherit (ds) mountPoint; }
              ] else [];
            in current ++ (flattenDatasets fullName ds.children)
          ) datasets);
      in lib.mkMerge (builtins.map (pool:
        let
          allMounts = flattenDatasets pool.poolName pool.datasets;
        in
          builtins.listToAttrs (builtins.map (mnt:
            lib.nameValuePair mnt.mountPoint {
              device = mnt.fullName;
              fsType = "zfs";
              options = [ "zfsutil" "nofail" ];
            }
          ) allMounts)
      ) cfg.storagePoolSchemas);
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

