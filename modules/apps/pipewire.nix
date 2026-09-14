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

  defaultOutput = cfg.defaultOutputAtBoot;
  defaultOutputType = if ((defaultOutput != null) && (defaultOutput.type == "bluetooth"))
                        then "bluez" else "alsa";

in {

  options.custom.apps.pipewire = {
    enable = lib.mkEnableOption "Enable the PipeWire sound server";

    enableAlsaLayer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route ALSA audio calls through PipeWire.";
    };

    enableAlsa32BitLayer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Route ALSA 32-bit audio calls through PipeWire.";
    };

    enablePulseLayer = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Route PulseAudio audio calls through PipeWire.";
    };

    defaultOutputAtBoot = lib.mkOption {
      default = null;
      description = "Always set this sound output as the default, on boot.";
      type = lib.types.nullOr (lib.types.submodule {
        # Note: you can test out the pactl devices and nodes that you find:
        #   1. pactl set-card-profile [device] [node]
        #   2. speaker-test -t wav

        options = {
          type = lib.mkOption {
            type = lib.types.enum [ "builtin_audio" "bluetooth" ];
            description = ''
              Default sound output hardware type.
                builtin_audio: motherboard 3.5mm, USB, HDMI, etc.
                bluetooth: motherboard bluetooth chip.
            '';
          };
          device = lib.mkOption {
            type = lib.types.str;
            description = ''
              Default sound output "device" (aka ALSA "card").
              In "pactl list cards" output, find suffix of the card "Name" property.
              e.g. "pci-0000_00_1f.3".
            '';
          };
          node = lib.mkOption {
            type = lib.types.str;
            description = ''
              Default sound output "node" (aka ALSA "device").
              In "pactl list cards" output, find "Profiles" entries marked with
              "available: yes" and look for for the starting "output:[node-name]" text.
              e.g. "analog-stereo", "hdmi-stereo".
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    services.pipewire = {
      enable = true;
      alsa.enable = cfg.enableAlsaLayer;
      alsa.support32Bit = cfg.enableAlsa32BitLayer;
      pulse.enable = cfg.enablePulseLayer;

      wireplumber.extraConfig."51-force-audio-profile" = lib.mkIf (defaultOutput != null) {
        # Ref: https://github.com/PipeWire/wireplumber/blob/master/src/config/wireplumber.conf
        "wireplumber.settings" = {
          # Do not restore a "default-audio-device" set at runtime from saved user state.
          "node.restore-default-targets" = false;
          # Do not restore the last active hardware configuration mode from saved user state.
          "device.restore-profile" = false;
          # Do not restore internal hardware paths (routes) or their tied volume states.
          "device.restore-routes" = false;
        };

        # These rules are evaluated on boot, and on any ALSA node change.
        # Ref: https://docs.pipewire.org/page_man_pipewire-props_7.html
        "monitor.${defaultOutputType}.rules" = [
          {
            matches = [
              { "device.name" = "${defaultOutputType}_card.${defaultOutput.device}"; }
            ];
            actions.update-props = {
              # Set the sound card's hardware mode. Specific software nodes (like HDMI)
              # only exist in the PipeWire graph if this underlying mode is active.
              "device.profile" = if defaultOutputType == "alsa" then
                                   "output:${defaultOutput.node}"
                                 else
                                   defaultOutput.node;
            };
          }
          {
            matches = [
              {
                "node.name" = "${defaultOutputType}_output.${defaultOutput.device}."
                              + "${defaultOutput.node}";
              }
            ];
            actions.update-props = {
              # Force this node to win the priority battle. Per PipeWire docs, max is 1500.
              "priority.session" = 1499;
              # Ignore per-node saved state files so our hardcoded priority strictly applies.
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

