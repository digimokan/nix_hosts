/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    imports: A list of other files or modules to include
    options: merged tree of all option _declarations_ across the system
    config: final, merged config tree of entire system, shared among modules
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

let

  cfg = config.custom.system.nixCore;

in {

  options.custom.system.nixCore = {
    enableUnifiedCli = lib.mkEnableOption "Enable the modern unified Nix CLI (nix-command)";
    enableFlakes = lib.mkEnableOption "Enable Nix flakes support";

    initialStateVersion = lib.mkOption {
      type = lib.types.str;
      description = "Nix version that apps will use for mutable data. Treat this as config 'born-on' date.";
    };
  };

  config = lib.mkMerge [
    {
      system.stateVersion = cfg.initialStateVersion;
    }

    (lib.mkIf cfg.enableUnifiedCli {
       nix.settings.experimental-features = [ "nix-command" ];
    })

    (lib.mkIf cfg.enableFlakes {
      nix.settings.experimental-features = [ "flakes" ];
    })
  ];

}

