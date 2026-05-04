{ ... }: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-eui.00000000000000000026b76876da41f5";
        content = {
          type = "gpt";
          partitions = {
            bios_boot = {
              size = "1M";
              type = "EF02";
            };
            ESP = {
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
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
      mountpoint = "/";
      rootFsOptions = {
        compression = "lz4";
        acltype = "posixacl";
        xattr = "sa";
        atime = "off";
      };
      datasets = {
        "var" = {
          type = "zfs_fs";
          mountpoint = "/var";
        };
      };
    };
  };
}

