{ config, lib, ... }:

let

  cfg = config.custom.system.networking;

in {

  options.custom.system.networking = {
    enable = lib.mkEnableOption "base networking configuration";
  };

  config = lib.mkIf cfg.enable {
    networking.useNetworkd = true;
    systemd.network.enable = true;
  };

}

