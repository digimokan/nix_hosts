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
        rootPoolDisksSel = [ "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F" ];
      };
    };
  in {
    nixosConfigurations.nas-0 = nixpkgs.lib.nixosSystem {
      system = allHostsSel.nas-0.systemArchSel;
      modules = [
        { _module.args.hostSel = allHostSel.nas-0; }
        disko.nixosModules.disko
        disko/zfs-single-disk.nix
        hosts/nas/configuration.nix
      ];
    };
  };
}

