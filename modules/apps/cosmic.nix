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

  cfg = config.custom.apps.cosmic;

in {

  options.custom.apps.cosmic = {
    enableDesktopEnv = lib.mkEnableOption "Enable the COSMIC Desktop Environment";

    enableDisplayMgr = lib.mkEnableOption "Enable the native COSMIC Greeter (Display Manager).";
  };

  config = lib.mkIf cfg.enableDesktopEnv {
    services.desktopManager.cosmic.enable = true;

    services.displayManager.cosmic-greeter.enable = cfg.enableDisplayMgr;

    custom.infrastructure.displayManager =
      lib.mkIf cfg.enableDisplayMgr "cosmic-greeter";

    assertions = [
      {
        assertion = config.custom.system.wayland.enableXWayland;
        message = (
          "COSMIC relies heavily on Wayland and XWayland for legacy apps. "
          + "Set `custom.system.wayland.enableXWayland = true` in your "
          + "host's composition root."
        );
      }
    ];
  };

}

