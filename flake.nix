{
  description = "My constellation of NixOS hosts";

  inputs = {
    # Note these input names, for all configuration that follows:
    #   -> Use "nixpkgs" for stable
    #   -> Use "nixos-unstable" for unstable
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
        specialArgs = { inherit inputs; };
        modules = [
          disko.nixosModules.disko
          ./hosts/nas/default.nix
          ./modules/default.nix
        ];
      };
    };
  };
}

