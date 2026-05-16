{ config, lib, pkgs, options, ... }:

{
  imports = [
    ./networking.nix
    ./nix-core.nix
    ./nixpkgs.nix
    ./sops.nix
    ./systemd-boot-efi.nix
  ];
}

