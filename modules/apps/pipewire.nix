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

  cfg = config.custom.apps.pipewire;

in {

  options.custom.apps.pipewire = {
    enable = lib.mkEnableOption "Enable the PipeWire sound server";

    enableAlsaCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route ALSA audio calls through PipeWire. Some older apps use ALSA.";
    };

    enableAlsa32BitCompat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable 32-bit ALSA support. Most older 32-bit Wine/Steam games use this.";
    };

    enablePulseCompat = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Create PulseAudio compatibility layer. Most desktop apps expect PulseAudio.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = cfg.enableAlsaCompat;
      alsa.support32Bit = cfg.enableAlsa32BitCompat;
      pulse.enable = cfg.enablePulseCompat;
    };

    assertions = [
      {
        assertion = config.custom.system.security.enableRtkit;
        message = (
          "Pipewire requires RTKit to prevent audio crackling. "
          + "Set `custom.system.security.enableRtkit = true` in your "
          + "host's composition root."
        );
      }
    ];
  };

}

