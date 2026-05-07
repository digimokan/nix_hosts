{ pkgs, perSystem, flake, ... }: {
  imports = [
    flake.inputs.disko.nixosModules.disko
  ];
}

