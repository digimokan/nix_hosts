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

    defaultSoundOutputAtBoot = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Set this Pipewire node as the default audio sink, at boot.
        Use "wpctl -n" to find node name, and "wpctl -k" for nicknames.
        e.g., alsa_output.pci-0000_00_1f.3.pro-output-3.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = cfg.enableAlsaCompat;
      alsa.support32Bit = cfg.enableAlsa32BitCompat;
      pulse.enable = cfg.enablePulseCompat;

      wireplumber.extraConfig."51-force-audio-profile" = lib.mkIf (cfg.defaultSoundOutputAtBoot != null) {
        "wireplumber.settings" = {
          "node.restore-default-targets" = false;
          "device.restore-profile" = false;
          "device.restore-routes" = false;
        };

        "monitor.alsa.rules" = [
          {
            matches = [ { "node.name" = cfg.defaultSoundOutputAtBoot; } ];
            actions.update-props = {
              "priority.session" = 1499;
              "state.restore-props" = false;
            };
          }
        ];
      };
    };

    assertions = [
      {
        assertion = config.custom.system.security.enableRealTimeKit;
        message = (
          "Pipewire requires RTKit to prevent audio crackling. "
          + "Set `custom.system.security.enableRtkit = true` in your "
          + "host's composition root."
        );
      }
    ];
  };

}

