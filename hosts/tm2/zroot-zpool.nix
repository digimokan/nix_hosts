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

let

  priUser = config.custom.infrastructure.primaryUser;
  hostName = config.networking.hostName;

in {

  poolName = "zroot";
  disks = [
    "/dev/disk/by-id/wwn-0x5000000123456789"
  ];

  rootFsEncryptionMethod = "passphrase";
  rootFsEncryptionSopsSecretName = "${hostName}_host_zfs_zroot_encryption_passphrase";

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
    {
      name = "home";
      mountPoint = "/home";
      owner = "root";
      group = "root";
      children = [
        {
          name = "${priUser}";
          mountPoint = "/home/${priUser}";
          owner = "${priUser}";
          group = "users";
        }
      ];
    }
  ];

}

