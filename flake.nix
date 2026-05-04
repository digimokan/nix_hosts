{
  description = "My constellation of NixOS hosts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # for master-key driven secrets
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # for rekeying all master-key driven secrets
    agenix-rekey.url = "github:oddlama/agenix-rekey";
    agenix-rekey.inputs.nixpkgs.follows = "nixpkgs";

    # for declarative disk formatting
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # for keeping flake.nix clean, by auto-loading a set of fixed dirs
    blueprint.url = "github:numtide/blueprint";
    blueprint.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs: let
    inherit (inputs.nixpkgs) lib;
    blueprint = inputs.blueprint { inherit inputs; };
  in {
    # blueprint automatically maps these dirs:
    #   checks, devshells, hosts, lib, modules, packages, templates
    inherit (blueprint) formatter lib nixosConfigurations;

    # map additional folders to custom outputs using logic in lib/
    inherit (inputs.self.lib) agenix-rekey nixosModules;

    # Secrets are encrypted based on a starting 32-byte hex string and this
    # derivation index.
    # Changing either the hex string or the derivation index will change the
    # encryption.
    derivationIndex = 1;
  };
}

