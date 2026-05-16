{ config, lib, pkgs, options, ... }:

let

  cfg = config.custom.system.nix;

in {

  options.custom.system.nix = {
    enableUnifiedCli = lib.mkEnableOption "Enable the modern unified Nix CLI (nix-command)";
    enableFlakes = lib.mkEnableOption "Enable Nix flakes support";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enableUnifiedCli {
       nix.settings.experimental-features = [ "nix-command" ];
    })

    (lib.mkIf cfg.enableFlakes {
      nix.settings.experimental-features = [ "flakes" ];
    })
  ];

}

