{
  imports = [
    ./disko-config.nix
  ];

  system.stateVersion = "24.05";

  custom.system.sops.enable = true;

  custom.system.systemdBootEfi.enable = true;

  custom.system.networking.hostName = "nas";
  custom.system.networking.hostId = "76755dca";

  custom.users.root.enable = true;
}

