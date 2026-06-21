/**
  params:
    lib: Nixpkgs library utility functions (like lib.mkIf)
    zpoolSchema: see storagePools.type in zfs.nix
  output (attribute set):
    An attribute set of disk(s) and filesystem(s) parsable by disko. Includes
      - Partitions suitable for GRUB bootloader.
      - Support for UEFI BIOS or Legacy BIOS.
      - A single-disk zpool, or two-disk mirror zpool.
      - The zpool 'zroot' mounted on root.
 */
{ lib }: zpoolSchema:

let

  diskCount = builtins.length zpoolSchema.disks;
  isMirror = diskCount == 2;
  disk1Id = builtins.elemAt zpoolSchema.disks 0;
  disk2Id = if isMirror then builtins.elemAt zpoolSchema.disks 1 else null;

  mkDisk = name: device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        # BIOS boot partition (for fallback/legacy)
        boot = {
          size = "1M";
          type = "EF02";
        };
        # EFI System Partition
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            # Grub mirrored boot requires distinct mountpoints to manage both bootloaders
            mountpoint = if name == "main" then "/boot" else "/boot-fallback";
            # "nofail" prevents booting in emergency mode.
            # "x-systemd.device-timeout=" is max wait time for partition mounting
            mountOptions = [ "defaults" "nofail" "x-systemd.device-timeout=5s" ];
          };
        };
        # ZFS partition
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = zpoolSchema.poolName;
          };
        };
      };
    };
  };

  flattenForDisko = parentPath: datasets:
    builtins.concatLists (builtins.map (ds:
      let
        fullPath = if parentPath == "" then ds.name else "${parentPath}/${ds.name}";
        current = lib.nameValuePair fullPath {
          type = "zfs_fs";
          mountpoint = ds.mountPoint;
          options = {
            compression = ds.compression;
            recordsize = ds.recordsize;
            exec = ds.exec;
            setuid = ds.setuid;
          };
        };
      in
        [ current ] ++ (flattenForDisko fullPath ds.children)
    ) datasets);

in {

  disko.devices = {

    # tmpfs RAM disk for the root filesystem, for use with impermanence
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [ "defaults" "size=4G" "mode=755" ];
    };

    # generate the primary disk, and conditionally append the secondary disk
    disk = {
      main = mkDisk "main" disk1Id;
    } // lib.optionalAttrs isMirror {
      secondary = mkDisk "secondary" disk2Id;
    };

    zpool."${zpoolSchema.poolName}" = {
      type = "zpool";
      mode = if isMirror then "mirror" else "";
      # best practice: top-level pool dataset is unmounted
      mountpoint = null;
      # pool-level options
      options = {
        ashift = builtins.toString zpoolSchema.poolAshift;
        compatibility = zpoolSchema.poolCompatibility;
      };
      rootFsOptions = {
        acltype = zpoolSchema.rootFsAclType;
        xattr = zpoolSchema.rootFsXattr;
        atime = zpoolSchema.rootFsAtime;
        compression = zpoolSchema.rootFsCompression;
      } // lib.optionalAttrs (zpoolSchema.rootFsEncryptionMethod == "passphrase") {
        encryption = "aes-256-gcm";
        keyformat = "passphrase";
        keylocation = "file://${zpoolSchema.rootFsEncryptionTempfilePath}";
      };
      # revert keylocation to standard prompt, so user can boot normally
      postCreateHook = lib.mkIf (zpoolSchema.rootFsEncryptionMethod == "passphrase")
        "zfs set keylocation=prompt ${zpoolSchema.poolName}";
      datasets = builtins.listToAttrs (flattenForDisko "" zpoolSchema.datasets);
    };

  };

}

