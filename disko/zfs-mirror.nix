{ myHost, ... }: {
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = builtins.elemAt myHost.rootPoolDisks 0;
        content = {
          type = "gpt";
          partitions = {
            bios_boot = { size = "1M"; type = "EF02"; };
            ESP = if myHost.isUefi then {
              size = "512M"; type = "EF00";
              content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot"; };
            } else {};
            zfs = { size = "100%"; content = { type = "zfs"; pool = "zroot"; }; };
          };
        };
      };
      secondary = {
        type = "disk";
        device = builtins.elemAt myHost.rootPoolDisks 1;
        content = {
          type = "gpt";
          partitions = {
            bios_boot = { size = "1M"; type = "EF02"; };
            ESP = if myHost.isUefi then {
              size = "512M"; type = "EF00";
              content = { type = "filesystem"; format = "vfat"; mountpoint = "/boot-fallback"; };
            } else {};
            zfs = { size = "100%"; content = { type = "zfs"; pool = "zroot"; }; };
          };
        };
      };
    };
    zpool.zroot = {
      type = "zpool";
      mode = "mirror";
      rootFsOptions = { compression = "lz4"; acltype = "posixacl"; xattr = "sa"; atime = "off"; };
      mountpoint = "/";
      datasets = {
        "root" = { type = "zfs_fs"; mountpoint = "/"; };
        "var" = { type = "zfs_fs"; mountpoint = "/var"; };
      };
    };
  };
}

