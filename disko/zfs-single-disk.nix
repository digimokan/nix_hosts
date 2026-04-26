disksSel: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # device = builtins.elemAt disksSel 0;
        device = "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F"
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

