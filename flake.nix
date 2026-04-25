{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
    hosts = {
      nas-0 = {
        hostname = "nas-0";
        zfsHostId = "21b841de";
        systemArchitecture = "x86_64-linux";
        isUefi = true;
        # Single 500GB NVME SSD:
        rootPoolDisks = [ "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F" ];
      };
    };
  in {
    nixosConfigurations.nas-0 = nixpkgs.lib.nixosSystem {
      system = hosts.nas-0.systemArchitecture;
      specialArgs = { inherit hosts; myHost = hosts.nas-0; };
      modules = [
        disko.nixosModules.disko
          ./disko/zfs-single-disk.nix
          ./hosts/nas/configuration.nix
      ];
    };
  };
}

