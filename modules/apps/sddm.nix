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

  cfg = config.custom.apps.sddm;

in {

  options.custom.apps.sddm = {
    enable = lib.mkEnableOption "Enable the SDDM Display Manager";

    enableWayland = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the SDDM login screen itself as a Wayland compositor rather than an X11 window.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = cfg.enableWayland;
    custom.infrastructure.displayManager = "sddm";
  };

}

