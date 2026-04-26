{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations.nas-0 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        ({
          disko.devices = {
            disk = {
              main = {
                type = "disk";
                device = "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F";
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

          boot.supportedFilesystems = [ "zfs" ];
          networking.hostName = "nas-0";
          networking.hostId = "21b841de";
          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          fileSystems."/data" = {
            device = "zdata";
            fsType = "zfs";
            options = [ "nofail" "canmount=on" ];
          };
          users.users.root.initialPassword = "nixos";
          system.stateVersion = "24.11";
        })
      ];
    };
  };
}

