{ config, flake, ... }: {

  services.tailscale = {
    enable = true;

    authKeyFile = config.age.secrets.tailscale-auth.path;

    extraSetFlags = [
      "--ssh"
    ];
  };

  age.secrets.tailscale-auth = {
    rekeyFile = flake + /secrets/shared/tailscale-auth.age;
    mode = "0400";
  };
}

