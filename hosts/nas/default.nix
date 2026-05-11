{
  imports = [
    ./disko-config.nix
  ];

  networking.hostName = "nas";

  custom.system.networking.enable = true;

  custom.users.root.enable = true;

  system.stateVersion = "24.05";
}

