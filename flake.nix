{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
  let
    allHostsSel = {
      nas-0 = {
        hostNameSel = "nas-0";
        hostIdSel = "21b841de";
        systemArchSel = "x86_64-linux";
        isUefiSel = true;
        diskoFileSel = ./disko/zfs-single-disk.nix;
        rootPoolDisksSel = [
          "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F"
        ];
      };
    };
  in {
    nixosConfigurations = builtins.mapAttrs (name: hostSel:
      nixpkgs.lib.nixosSystem {
        system = hostSel.systemArchSel;
        specialArgs = { inherit hostSel; };
        modules = [
          disko.nixosModules.disko
          (import hostSel.diskoFileSel hostSel.rootPoolDisksSel)
          ./hosts/nas/configuration.nix
        ];
      }
    ) allHostsSel;
  };
}

