{ inputs, ... }: {
  # make pkgs.unstable available in any module
  nixpkgs.overlays = [
    (final: prev: {
      unstable = import inputs.nixpkgs-unstable {
        system = prev.system;
      };
    })
  ];
}

