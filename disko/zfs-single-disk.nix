{ hostSel, ... }: {
  disko.devices = {
    disk.main = {
      type = "disk";
      device = builtins.elemAt hostSel.rootPoolDisksSel 0;
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
