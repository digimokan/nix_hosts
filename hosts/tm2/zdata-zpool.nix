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
  poolName = "zdata_tm2";
  disks = [
    "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b4f06150c"
  ];

  rootFsEncryptionMethod = "keyfile";
  rootFsEncryptionSopsSecretName = "tm2_host_zfs_zdata_encryption_symkey";

  datasets = [
    {
      name = "home";
      mountPoint = "/home";
      children = [
        {
          name = "testuser2";
        }
      ];
    }
  ];

}

