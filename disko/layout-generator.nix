/**
  params:
    lib: Nixpkgs library utility functions (like lib.mkIf)
    diskIds: A list of strings representing the physical device paths.
      * To obtain the Disk ID, run 'ls -l /dev/disk/by-id/':
          - SATA SSDs:      use ID prefixed with 'wwn-'
          - USB Enclosures: use ID prefixed with 'wwn-'
          - NVME SSDs:      use ID prefixed with 'nvme-eui.'
          - USB Sticks:     use ID prefixed with 'usb-'
  output (attribute set):
    An attribute set of disk(s) and filesystem(s) parsable by disko. Includes
      - Partitions suitable for GRUB bootloader.
      - Support for UEFI BIOS or Legacy BIOS.
      - A single-disk zpool, or two-disk mirror zpool.
      - The zpool 'zroot' mounted on root.
*/
{ lib }:
diskIds:

let
  diskCount = builtins.length diskIds;
  isMirror = diskCount == 2;

  # Extract paths from the parameter list
  disk1Id = builtins.elemAt diskIds 0;
  disk2Id = if isMirror then builtins.elemAt diskIds 1 else null;

  # Helper function: Generates the identical GPT partition structures for each drive
  mkDisk = name: device: {
    type = "disk";
    inherit device;
    content = {
      type = "gpt";
      partitions = {
        boot = {
          size = "1M";
          type = "EF02"; # BIOS boot partition (for fallback/legacy)
        };
        ESP = {
          size = "1G";
          type = "EF00"; # EFI System Partition
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
        zfs = {
          size = "100%";
          content = {
            type = "zfs";
            pool = "zroot";
          };
        };
      };
    };
  };

in {
  disko.devices = {
    # tmpfs RAM disk for the root filesystem, for use with impermanence
    nodev."/" = {
      fsType = "tmpfs";
      mountOptions = [
        "defaults"
        "size=4G"
        "mode=755"
      ];
    };

    # Generate the primary disk, and conditionally append the secondary disk
    disk = {
      main = mkDisk "main" disk1Id;
    } // lib.optionalAttrs isMirror {
      secondary = mkDisk "secondary" disk2Id;
    };

    zpool.zroot = {
      type = "zpool";
      mode = if isMirror then "mirror" else "";
      # Best practice: top-level pool dataset is unmounted
      mountpoint = null;
      rootFsOptions = {
        compression = "lz4";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
      };
      datasets = {
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          # Apply highly-efficient zstd compression specifically to the Nix store
          options = {
            compression = "zstd";
          };
        };
        "var" = {
          type = "zfs_fs";
          mountpoint = "/var";
        };
        # impermanence: persist data from "/" (e.g. /etc/xxxx) into this dataset
        "persist" = {
          type = "zfs_fs";
          mountpoint = "/persist";
        };
      };
    };
  };
}

