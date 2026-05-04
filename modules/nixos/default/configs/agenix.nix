{ config, flake, ... }: {

  # Globally import the agenix engines and the /secrets folder into
  # every host automatically.
  imports = [
    flake.inputs.agenix.nixosModules.default
    flake.inputs.agenix-rekey.nixosModules.default
    (flake + /secrets)
  ];

  # Setup the root password using standard NixOS/Agenix.
  age.secrets.root-password = {
    rekeyFile = flake + /secrets/nixos/${config.networking.hostName}/root-password.age;
  };

  users.users.root = {
    hashedPasswordFile = config.age.secrets.root-password.path;
  };
}

