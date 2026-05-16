/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
    <special args>: individual named args, via specialArgs and '...'.
  output (attribute set):
    imports: A list of other files or modules to include
    options: merged tree of all option _declarations_ across the system
    config: final, merged config tree of entire system, shared among modules
*/
{ config, lib, pkgs, options, ... }:

let

  cfg = config.custom.apps.tailscale;

in {

  options.custom.apps.tailscale = {
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

