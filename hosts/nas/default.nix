{ config, lib, pkgs, options, ... }:

{

  imports = [
    ./disko-config.nix
  ];

  config = {
    system.stateVersion = "24.05";

    custom.system.nix.enableUnifiedCli = true;
    custom.system.nix.enableFlakes = true;

    custom.system.sops.enable = true;

    custom.system.systemdBootEfi.enable = true;

    custom.system.timezone = "US/Central";

    custom.system.networking.hostName = "nas";
    custom.system.networking.hostId = "76755dca";

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = config.sops.secrets.server_host_tailscale_auth_key.path;

    custom.users.root.enable = true;
  };

}

