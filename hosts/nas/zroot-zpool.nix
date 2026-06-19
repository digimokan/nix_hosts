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

  poolName = "zroot";
  disks = [
    "/dev/disk/by-id/wwn-0x5001b448c8589b8d"
    "/dev/disk/by-id/wwn-0x5001b448c8e4e17e"
  ];

  rootFsEncryptionMethod = "none";

  datasets = [
    {
      name = "nix";
      mountPoint = "/nix";
      compression = "zstd";
    }
    {
      name = "var";
      mountPoint = "/var";
    }
    {
      name = "persist";
      mountPoint = "/persist";
    }
  ];

}

