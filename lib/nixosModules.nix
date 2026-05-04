# ref: https://github.com/suderman/nixos/blob/main/lib/nixosModules.nix
{inputs, ...}: let
pathAttrs = path:
inputs.blueprint.lib.importDir path
(inputs.nixpkgs.lib.mapAttrs (_name: {path, ...}: path));
in {
  default = ../modules/nixos/default;
  desktop = pathAttrs ../modules/nixos/desktop;
  hardware = pathAttrs ../modules/nixos/hardware;
}
