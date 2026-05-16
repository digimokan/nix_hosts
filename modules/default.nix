{ config, lib, pkgs, options, ... }:

{
  imports = [
    ./apps/default.nix
    ./system/default.nix
    ./users/default.nix
  ];
}

