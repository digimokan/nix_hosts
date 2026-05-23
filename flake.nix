/**
  This flake.nix file is an attribute set with three attributes:
    description: A description of the flake.
    inputs:      Repo urls for official or custom nix package sources.
    outputs:     A function that uses the inputs to produce a
                 an attribute set that contains system configurations.
 */
 {

  description = "My constellation of NixOS hosts";

  inputs = {
    # versioned stable branch packages: access this via pkgs.stable overlay.
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    # unstable branch packages: access this via pkgs.unstable overlay.
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs-unstable";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-unstable";

    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs.nixpkgs.follows = "nixpkgs-unstable";
    impermanence.inputs.home-manager.follows = "nixpkgs-unstable";
  };

  /**
    The lib.nixosSystem function is the core builder in Nixpkgs used to
    evaluate and generate a complete NixOS system configuration. It evaluates a
    list of modules, resolves the module system, and produces a complete system
    derivation including all packages, configuration files, and the bootable
    system closure.

    nixosSystem operates on an attribute set with these inputs:
      system:
        The target architecture platform (e.g. "aarch64-linux").
      specialArgs
        An attribute set of additional arguments passed to all imported
        modules. This is often used to inject flake inputs into your
        configuration.
      modules:
        A list of NixOS modules. Your configuration files (e.g.
        /etc/nixos/configuration.nix) act as top-level modules and are placed
        here. nixosSystem automatically provides these arguments to modules:
          config:
            The final, merged configuration tree of the entire system.
            This allows one module to read settings defined in another module.
          lib:
            The Nixpkgs library utility functions (like lib.mkIf).
          pkgs:
            The fully configured Nixpkgs package set, based on "system".
          options:
            The merged tree of all option definitions across the system
            (mostly used for advanced debugging).
          <special args>
            Individual named args, via specialArgs.

    nixosSystem produces these outputs, used by various "nix flake" commands:
      packages.<system>.<hostname>:
        Definitions for software packages.
        The default package is built by nix build.
      apps.<system>.<hostname>:
        Definitions for executable programs.
        The default app is run by nix run.
      devShells.<system>.<hostname>:
        Shell environments for development, typically containing specific build
        tools or libraries.
      nixosConfigurations.<hostname>:
        Full NixOS system configurations.
      templates.<hostname>:
        Boilerplate project starters used for initializing new flakes.
      checks.<system>.<hostname>:
        Automated tests or derivations that must succeed for a "clean"
        flake evaluation.
      lib.<hostname>:
        Helper functions or libraries intended for use by other flakes.
  */
  outputs = { self, nixpkgs, nixpkgs-unstable, disko, sops-nix, ... } @inputs:
    let
      # Build systems using the unstable branch.
      # Individual modules and packages can still select the overlays
      # for pkgs.stable and pkgs.unstable.
      mkSystem = hostName: nixpkgs-unstable.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          { networking.hostName = hostName; }
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          impermanence.nixosModules.impermanence
          ./modules/default.nix
          ./hosts/${hostName}/default.nix
        ];
      };
    in {
      nixosConfigurations = {
        nas = mkSystem "nas";
      };
    };

}

