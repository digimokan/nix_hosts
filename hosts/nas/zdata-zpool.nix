/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    zpoolSchema: see storagePools.type in zfs.nix
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

{

  poolName = "zdata_nas";
  disks = [
    "/dev/disk/by-id/wwn-0x5000cca418c6f46f"
  ];

  rootFsEncryptionMethod = "none";

  datasets = [
    {
      name = "data";
      mountPoint = "/data";
      children = [
        {
          name = "Movies";
          recordsize = "1M";
          exec = "off";
          setuid = "off";
        }
        {
          name = "Pictures";
          recordsize = "1M";
          exec = "off";
          setuid = "off";
        }
        {
          name = "Shows";
          recordsize = "1M";
          exec = "off";
          setuid = "off";
        }
        {
          name = "HomeVideos";
          recordsize = "1M";
          exec = "off";
          setuid = "off";
        }
        {
          name = "Software";
          recordsize = "128K";
        }
      ];
    }
  ];

}

