{ config, lib, pkgs, options, ... }:

{

  imports = [
    ./disko-config.nix
  ];

  config = {
    system.stateVersion = "24.05";

    custom.system.sops.enable = true;

    custom.system.systemdBootEfi.enable = true;

    custom.system.networking.hostName = "nas";
    custom.system.networking.hostId = "76755dca";

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sops.secrets.server_host_tailscale_auth_key.path;

    custom.users.root.enable = true;
  };

}

