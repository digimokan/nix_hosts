/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    imports: A list of other files or modules to include
    options: merged tree of all option _declarations_ across the system
    config: final, merged config tree of entire system, shared among modules
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

{
  config = {
    disko.devices = {
      disk = {
        main = {
          type = "disk";
          # To obtain the Disk ID, run 'ls -l /dev/disk/by-id/':
          #   * SATA SSD and USB Enclosures: use ID prefixed with 'ata-'
          #   * NVME: use ID prefixed with 'nvme-eui.'
          #   * USB Drives (not in Enclosures): use ID prefixed with 'usb-'
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
        # best practice: top-level pool dataset is unmounted
        mountpoint = "none";
        rootFsOptions = {
          compression = "lz4";
          acltype = "posixacl";
          xattr = "sa";
          atime = "off";
        };
        datasets = {
          "nixos" = {
            type = "zfs_fs";
            mountpoint = "/";
          };
          "nix" = {
            type = "zfs_fs";
            mountpoint = "/nix";
            # apply highly-efficient zstd compression to the Nix store
            options = {
              compression = "zstd";
            };
          };
          "var" = {
            type = "zfs_fs";
            mountpoint = "/var";
          };
        };
      };
    };
  };
}

