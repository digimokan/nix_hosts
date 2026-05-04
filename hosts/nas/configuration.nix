{ config, flake, ... }: {
  imports = [
    ./disk-config.nix
    flake.nixosModules.default
  ];

  # Bootloader settings.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Enable SSH server.
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes"; # TODO: just for initial FreeBSD setup
  };

  # pin the version of "configuration defaults" we are using
  system.stateVersion = "24.05";
}

