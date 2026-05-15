{ config, lib, ... }:

let

  cfg = config.custom.apps.tailscale;
  opts = options.custom.apps.tailscale;

in {

  opts = {
    enable = lib.mkEnableOption "Enable Tailscale client and daemon.";

    enableSshServer = lib.mkEnableOption "Enable Tailscale SSH server (--ssh).";

    enableShieldsUp = lib.mkEnableOption "Block incoming LAN connections (--shields-up).";

    authKeyPath = lib.mkOption {
      type = lib.types.str;
      description = "Auth key to authenticate and join the tailnet.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale = {
      enable = true;
      authKeyFile = cfg.authKeyPath;
      extraUpFlags =
        (lib.optional cfg.enableSshServer "--ssh") ++
        (lib.optional cfg.enableShieldsUp "--shields-up");
    };
  };

}

