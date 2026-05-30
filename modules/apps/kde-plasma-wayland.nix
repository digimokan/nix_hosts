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

  cfg = config.custom.apps.kdePlasmaWayland;

in {

  options.custom.apps.kdePlasmaWayland = {
    enable = lib.mkEnableOption "Enable KDE Plasma 6 (defaults to native Wayland session)";
  };

  config = lib.mkIf cfg.enable {
    services.desktopManager.plasma6.enable = true;

    assertions = [
      {
        assertion = config.custom.system.wayland.enableXWayland;
        message = (
          "KDE relies on XWayland for many legacy UI components. "
          + "Set `custom.system.wayland.enableXWayland = true` in your "
          + "host's composition root."
        );
      }
    ];
  };

}

