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
  hasDefaultInputOrOutput = (cfg.defaultOutput != null) || (cfg.defaultInput != null);

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

    defaultOutput = lib.mkOption {
      default = null;
      description = ''
        Set this sound output as the default on user login, or whenever
        the output appears (e.g. USB speaker is plugged in).
      '';
      type = lib.types.nullOr (lib.types.submodule {
        # Note: you can test out the pactl devices and nodes that you find:
        #   1. pactl set-card-profile [device] [node]
        #   2. speaker-test -t wav

        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = ''
              Default sound output "device" (aka ALSA "card").
              In "pactl list cards" output, find suffix of the card "Name" property.
              e.g. "pci-0000_00_1f.3".
            '';
          };

          deviceType = lib.mkOption {
            type = lib.types.enum [ "alsa" "bluez" ];
            description = ''
              Default sound output hardware type.
                alsa: built-in motherboard 3.5mm, USB, HDMI, etc.
                bluez: built-in motherboard bluetooth chip.
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

          volume = lib.mkOption {
            type = lib.types.ints.between 0 100;
            description = "Default sound output volume to set at boot.";
          };
        };
      });
    };

    defaultInput = lib.mkOption {
      default = null;
      description = ''
        Set this sound input as the default on user login, or whenever
        the input appears (e.g. USB microphone is plugged in).
      '';
      type = lib.types.nullOr (lib.types.submodule {
        # Note: you can test out the pactl devices and nodes that you find:
        #   1. pactl set-card-profile [device] [node]
        #   2. arecord -f cd -d 5 test.wav && aplay test.wav

        options = {
          device = lib.mkOption {
            type = lib.types.str;
            description = ''
              Default sound input "device" (aka ALSA "card").
              In "pactl list cards" output, find suffix of the card "Name" property.
              e.g. "usb-4K_USB_Camera_4K_USB_Camera_01.00.00-02".
            '';
          };

          deviceType = lib.mkOption {
            type = lib.types.enum [ "alsa" "bluez" ];
            description = ''
              Default sound input hardware type.
                alsa: built-in motherboard 3.5mm, USB, HDMI, etc.
                bluez: built-in motherboard bluetooth chip.
            '';
          };

          node = lib.mkOption {
            type = lib.types.str;
            description = ''
              Default sound input "node" (aka ALSA "device").
              In "pactl list cards" output, find "Profiles" entries marked with
              "available: yes" and look for for the starting "input:[node-name]" text.
              e.g. "analog-stereo".
            '';
          };

          volume = lib.mkOption {
            type = lib.types.ints.between 0 100;
            description = "Default sound input volume to set at boot.";
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

      wireplumber.extraConfig."50-declarative-defaults-policy" = lib.mkIf hasDefaultInputOrOutput {
        # Ref: https://github.com/PipeWire/wireplumber/blob/master/src/config/wireplumber.conf
        "wireplumber.settings" = {
          # Do not restore a "default-audio-device" set at runtime from saved user state.
          "node.restore-default-targets" = false;
          # Do not restore the last active hardware configuration mode from saved user state.
          "device.restore-profile" = false;
          # Do not restore internal hardware paths (routes) or their tied volume states.
          "device.restore-routes" = false;
        } // lib.optionalAttrs (cfg.defaultOutput != null) {
          # Set the volume on the sink.
          # Convert user input linear-scale volume percent to PipeWire cubic-scale volume.
          "device.routes.default-sink-volume" = let
            v = cfg.defaultOutput.volume / 100.0;
          in
            v * v * v;
        } // lib.optionalAttrs (cfg.defaultInput != null) {
          # Set the volume on the source.
          # Convert user input linear-scale volume percent to PipeWire cubic-scale volume.
          "device.routes.default-source-volume" = let
            v = cfg.defaultInput.volume / 100.0;
          in
            v * v * v;
        };
      };

      # Monitor rules are evaluated when a hardware node is created (e.g., at
      #   user login or device hotplug).
      # Ref: https://docs.pipewire.org/page_man_pipewire-props_7.html
      # Ref: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/alsa.html

      wireplumber.extraConfig."51-force-audio-output" = lib.mkIf (cfg.defaultOutput != null) {
        "monitor.${cfg.defaultOutput.deviceType}.rules" = [
          {
            matches = [
              { "device.name" = "${cfg.defaultOutput.deviceType}_card.${cfg.defaultOutput.device}"; }
            ];
            actions.update-props = {
              # Set the sound card's hardware mode. Specific software nodes (like HDMI)
              # only exist in the PipeWire graph if this underlying mode is active.
              "device.profile" = if cfg.defaultOutput.deviceType == "alsa" then
                                   "output:${cfg.defaultOutput.node}"
                                 else
                                   cfg.defaultOutput.node;
            };
          }
          {
            matches = [
              {
                "node.name" = "${cfg.defaultOutput.deviceType}_output.${cfg.defaultOutput.device}."
                              + "${cfg.defaultOutput.node}";
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

      wireplumber.extraConfig."52-force-audio-input" = lib.mkIf (cfg.defaultInput != null) {
        "monitor.${cfg.defaultInput.deviceType}.rules" = [
          {
            matches = [
              { "device.name" = "${cfg.defaultInput.deviceType}_card.${cfg.defaultInput.device}"; }
            ];
            actions.update-props = {
              # Set the sound card's hardware mode. Specific software nodes (like analog-stereo)
              # only exist in the PipeWire graph if this underlying mode is active.
              "device.profile" = if cfg.defaultInput.deviceType == "alsa" then
                                   "input:${cfg.defaultInput.node}"
                                 else
                                   cfg.defaultInput.node;
            };
          }
          {
            matches = [
              {
                "node.name" = "${cfg.defaultInput.deviceType}_input.${cfg.defaultInput.device}."
                              + "${cfg.defaultInput.node}";
              }
            ];
            actions.update-props = {
              # Force this node to win the priority battle. Sources default to 1600-2000.
              "priority.session" = 2499;
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

