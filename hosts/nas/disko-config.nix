{
  config = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          # To obtain the Disk ID, run 'ls -l /dev/disk/by-id/':
          #   * SATA SSDs:      use ID prefixed with 'wwn-'
          #   * USB Enclosures: use ID prefixed with 'wwn-'
          #   * NVME SSDs:      use ID prefixed with 'nvme-eui.'
          #   * USB Sticks:     use ID prefixed with 'usb-'
          device = "/dev/disk/by-id/wwn-0x5001b448c8589b8d";
          content = {
            type = "gpt";
            partitions = {
              boot = {
                size = "1M";
                type = "EF02";
              };
              ESP = {
                size = "1G";
                type = "EF00";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                  mountOptions = [ "defaults" ];
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
      };
      zpool.zroot = {
        type = "zpool";
        mode = "";
        # best practice: top-level pool dataset is unmounted
        mountpoint = null;
        rootFsOptions = {
          compression = "lz4";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
        };
        datasets = {
          "nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            # apply highly-efficient zstd compression to the Nix store
            options = {
              compression = "zstd";
            };
          };
          "var" = {
            type = "zfs_fs";
            mountpoint = "/var";
          };
        };
      };
    };
  };
}

