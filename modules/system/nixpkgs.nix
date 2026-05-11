{ lib, ... }: {
  nixpkgs.config = {
    allowUnfree = false;
  };
}

