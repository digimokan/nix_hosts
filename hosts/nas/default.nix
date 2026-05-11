{ hostName, ... }: {
  imports = [
    ./disko-config.nix
  ];

  system.stateVersion = "24.05";

  custom.system.boot.enable = true;
  custom.system.networking.enable = true;
  custom.system.networking.hostName = hostName;
  custom.users.root.enable = true;
}

