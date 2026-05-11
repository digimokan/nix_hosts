{
  description = "My constellation of NixOS hosts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, disko, ... } @inputs: {
    nixosConfigurations = {
      nas = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          inherit inputs;
          hostName = "nas";
        };
        modules = [
          disko.nixosModules.disko
          ./hosts/nas/default.nix
          ./modules/default.nix
        ];
      };
    };
  };
}

