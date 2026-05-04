# ref: suderman/nixos/modules/nixos/default/default.nix
{...}: {
# Evaluate all .nix files inside these three folders:
  imports = [
    ./configs
    ./options
    ./overlays
  ];
}

