{ flake, inputs, ... }: let
  inherit (inputs.nixpkgs) lib;
  args = { inherit flake inputs lib; };
in rec {

  /**
    An extension of nixpkgs' lib.genAttrs.
    Converts lists, paths, or attrs to a list, strips ".nix" suffixes,
    and applies the function. Used to mass-generate configs.

  # Type
  ```
  genAttrs :: (list | path | attrs) -> (string -> any) -> attrs
  ```
  */
  genAttrs = import ./genAttrs.nix args;

  /**
    A customized filesystem crawler.
    Allows recursive searching for Nix files while filtering specific dirs.
    Used to auto-discover secret files in the /secrets directory.
   */
  ls = import ./ls.nix args;

  # Maps the `modules/nixos` dir into standard NixOS flake outputs.
  nixosModules = import ./nixosModules.nix args;

  # The core configuration for the agenix-rekey tool.
  # Binds the flake's hosts to the rekeying tool so it knows where to build
  # secrets.
  agenix-rekey = inputs.agenix-rekey.configure {
    userFlake = flake;
    inherit (flake) nixosConfigurations;
  };
}

