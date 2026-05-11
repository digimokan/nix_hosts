{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-eui.00000000000000000026b76876da41f5";
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
      mountpoint = "/";
      rootFsOptions = {
        compression = "lz4";
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

