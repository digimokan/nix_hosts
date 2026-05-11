{
  imports = [
    ./disko-config.nix
  ];

  system.stateVersion = "24.05";

  custom.system.sops.enable = true;

  custom.system.systemdBootEfi.enable = true;

  custom.system.networking.enable = true;
  custom.system.networking.hostName = "nas";

  custom.users.root.enable = true;
}

