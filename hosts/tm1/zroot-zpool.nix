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
    "/dev/disk/by-id/usb-USB_SanDisk_3.2Gen1_040146c9b17f85ade27490b1e2e2067a0ec16ebed365169889067fcb0c02b6b851ff00000000000000000000e630da08008e6d1883558107822ef147-0:0"
  ];

  rootFsEncryptionMethod = "passphrase";
  rootFsEncryptionSopsSecretName = "tm1_host_zfs_zroot_encryption_passphrase";

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

