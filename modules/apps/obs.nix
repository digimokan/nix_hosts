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

  cfg = config.custom.apps.obs;
  homeMgrUsers = config.custom.system.homeManager.enableForUsers;

in {

  options.custom.apps.obs = {
    enableForUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users to install and configure OBS Studio profiles for.";
    };

    userSettings = lib.mkOption {
      description = "Per-user OBS configurations, for overriding defaults.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          videoSaveDir = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Directory where recorded videos are saved. Defaults to /home/<user>/Videos.";
          };

          videoRecFormat = lib.mkOption {
            type = lib.types.enum [ "mkv" "mpegts" "mp4" "mov" "flv" ];
            default = "mkv";
            description = ''
              Video recording format container:
                mkv (Matroska Video)
                mpegts (MPEG-Transport-Stream)
                mp4 (MPEG-4)
                mov (QuickTime)
                flv (Flash Video)
            '';
          };

          videoRecQuality = lib.mkOption {
            type = lib.types.enum [ "Small" "Stream" "HQ" "Lossless" ];
            default = "Small";
            description = ''
              Video recording quality preset.
                Small (high quality, medium file size)
                Stream (same as input quality)
                HQ (indistinguishable quality, large file size)
                Lossless (true lossless quality, extremely large file size)
            '';
          };

          hotkeyRecStart = lib.mkOption {
            type = lib.types.str;
            default = "OBS_KEY_F7";
            description = "Hotkey binding to start recording.";
          };

          hotkeyRecStop = lib.mkOption {
            type = lib.types.str;
            default = "OBS_KEY_F7";
            description = "Hotkey binding to stop recording.";
          };

          hotkeyRecPause = lib.mkOption {
            type = lib.types.str;
            default = "OBS_KEY_F9";
            description = "Hotkey binding to pause recording.";
          };

          hotkeyRecUnpause = lib.mkOption {
            type = lib.types.str;
            default = "OBS_KEY_F9";
            description = "Hotkey binding to unpause recording.";
          };
        };
      });
    };
  };

  config = lib.mkIf (builtins.length cfg.enableForUsers > 0) {
    environment.systemPackages = [ pkgs.obs-studio ];

    custom.apps.obs.userSettings = lib.genAttrs cfg.enableForUsers (u: {});

    assertions = [
      {
        assertion = lib.all (user: lib.elem user homeMgrUsers) cfg.enableForUsers;
        message = (
          "A user configured in custom.apps.obs.enableForUsers lacks Home Manager "
          + "enablement in custom.system.homeManager.enableForUsers."
        );
      }
    ];

    home-manager.users = lib.genAttrs cfg.enableForUsers (userName:
      let
        userCfg = cfg.userSettings.${userName};
        # Helper to generate the exact JSON string required by OBS INI files
        mkHotkey = key: builtins.toJSON { bindings = [ { inherit key; } ]; };
      in {
        xdg.configFile."obs-studio/basic/profiles/Untitled/basic.ini" = {
          force = true;
          text = lib.generators.toINI {} {
            Output = {
              Mode = "Simple";
            };
            SimpleOutput = {
              FilePath = if (userCfg.videoSaveDir != null) then
                           userCfg.videoSaveDir
                         else
                           "/home/${userName}/Videos";
              RecFormat2 = userCfg.videoRecFormat;
              RecQuality = userCfg.videoRecQuality;
            };
            Hotkeys = {
              "OBSBasic.StartRecording" = mkHotkey userCfg.hotkeyRecStart;
              "OBSBasic.StopRecording" = mkHotkey userCfg.hotkeyRecStop;
              "OBSBasic.PauseRecording" = mkHotkey userCfg.hotkeyRecPause;
              "OBSBasic.UnpauseRecording" = mkHotkey userCfg.hotkeyRecUnpause;
            };
          };
        };

        xdg.configFile."obs-studio/basic/scenes/Untitled.json" = {
          force = true;
          text = ''
            {
              "name": "Untitled",
              "DesktopAudioDevice1": {
                "prev_ver": 536936450,
                "name": "Desktop Audio",
                "uuid": "8e92e09d-466f-4eaf-993b-bfec884bd039",
                "id": "pulse_output_capture",
                "versioned_id": "pulse_output_capture",
                "settings": {
                  "device_id": "default"
                },
                "mixers": 255,
                "sync": 0,
                "flags": 0,
                "volume": 1.0,
                "balance": 0.5,
                "enabled": true,
                "muted": false,
                "push-to-mute": false,
                "push-to-mute-delay": 0,
                "push-to-talk": false,
                "push-to-talk-delay": 0,
                "hotkeys": {
                  "libobs.mute": [],
                  "libobs.unmute": [],
                  "libobs.push-to-mute": [],
                  "libobs.push-to-talk": []
                },
                "deinterlace_mode": 0,
                "deinterlace_field_order": 0,
                "monitoring_type": 0,
                "private_settings": {}
              },
              "AuxAudioDevice1": {
                "prev_ver": 536936450,
                "name": "Mic/Aux",
                "uuid": "8deadf6e-78a2-4d90-8b76-36b1d3e9a8b4",
                "id": "pulse_input_capture",
                "versioned_id": "pulse_input_capture",
                "settings": {
                  "device_id": "default"
                },
                "mixers": 255,
                "sync": 0,
                "flags": 0,
                "volume": 1.0,
                "balance": 0.5,
                "enabled": true,
                "muted": false,
                "push-to-mute": false,
                "push-to-mute-delay": 0,
                "push-to-talk": false,
                "push-to-talk-delay": 0,
                "hotkeys": {
                  "libobs.mute": [],
                  "libobs.unmute": [],
                  "libobs.push-to-mute": [],
                  "libobs.push-to-talk": []
                },
                "deinterlace_mode": 0,
                "deinterlace_field_order": 0,
                "monitoring_type": 0,
                "private_settings": {}
              },
              "sources": [
                {
                  "prev_ver": 536936450,
                  "name": "Audio Input Capture (PulseAudio)",
                  "uuid": "700459b7-600a-426f-b66c-360846484b74",
                  "id": "pulse_input_capture",
                  "versioned_id": "pulse_input_capture",
                  "settings": {},
                  "mixers": 255,
                  "sync": 0,
                  "flags": 0,
                  "volume": 1.0,
                  "balance": 0.5,
                  "enabled": true,
                  "muted": false,
                  "push-to-mute": false,
                  "push-to-mute-delay": 0,
                  "push-to-talk": false,
                  "push-to-talk-delay": 0,
                  "hotkeys": {
                    "libobs.mute": [],
                    "libobs.unmute": [],
                    "libobs.push-to-mute": [],
                    "libobs.push-to-talk": []
                  },
                  "deinterlace_mode": 0,
                  "deinterlace_field_order": 0,
                  "monitoring_type": 0,
                  "private_settings": {}
                },
                {
                  "prev_ver": 536936450,
                  "name": "Webcam",
                  "uuid": "b7ece202-0565-4dc8-9afc-8277a9d09f7a",
                  "id": "v4l2_input",
                  "versioned_id": "v4l2_input",
                  "settings": {
                    "device_id": "/dev/video0",
                    "input": 0,
                    "pixelformat": 1196444237
                  },
                  "mixers": 0,
                  "sync": 0,
                  "flags": 0,
                  "volume": 1.0,
                  "balance": 0.5,
                  "enabled": true,
                  "muted": false,
                  "push-to-mute": false,
                  "push-to-mute-delay": 0,
                  "push-to-talk": false,
                  "push-to-talk-delay": 0,
                  "hotkeys": {},
                  "deinterlace_mode": 0,
                  "deinterlace_field_order": 0,
                  "monitoring_type": 0,
                  "private_settings": {}
                },
                {
                  "prev_ver": 536936450,
                  "name": "Scene",
                  "uuid": "bfb37e1f-9042-44db-9fa9-2311b8c50d83",
                  "id": "scene",
                  "versioned_id": "scene",
                  "settings": {
                    "id_counter": 2,
                    "custom_size": false,
                    "items": [
                      {
                        "name": "Audio Input Capture (PulseAudio)",
                        "source_uuid": "700459b7-600a-426f-b66c-360846484b74",
                        "visible": true,
                        "locked": false,
                        "rot": 0.0,
                        "scale_ref": {
                          "x": 1920.0,
                          "y": 1080.0
                        },
                        "align": 5,
                        "bounds_type": 0,
                        "bounds_align": 0,
                        "bounds_crop": false,
                        "crop_left": 0,
                        "crop_top": 0,
                        "crop_right": 0,
                        "crop_bottom": 0,
                        "id": 1,
                        "group_item_backup": false,
                        "pos": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "pos_rel": {
                          "x": -1.7777777910232544,
                          "y": -1.0
                        },
                        "scale": {
                          "x": 1.0,
                          "y": 1.0
                        },
                        "scale_rel": {
                          "x": 1.0,
                          "y": 1.0
                        },
                        "bounds": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "bounds_rel": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "scale_filter": "disable",
                        "blend_method": "default",
                        "blend_type": "normal",
                        "show_transition": {
                          "duration": 300
                        },
                        "hide_transition": {
                          "duration": 300
                        },
                        "private_settings": {}
                      },
                      {
                        "name": "Webcam",
                        "source_uuid": "b7ece202-0565-4dc8-9afc-8277a9d09f7a",
                        "visible": true,
                        "locked": false,
                        "rot": 0.0,
                        "scale_ref": {
                          "x": 1920.0,
                          "y": 1080.0
                        },
                        "align": 5,
                        "bounds_type": 0,
                        "bounds_align": 0,
                        "bounds_crop": false,
                        "crop_left": 0,
                        "crop_top": 0,
                        "crop_right": 0,
                        "crop_bottom": 0,
                        "id": 2,
                        "group_item_backup": false,
                        "pos": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "pos_rel": {
                          "x": -1.7777777910232544,
                          "y": -1.0
                        },
                        "scale": {
                          "x": 0.5,
                          "y": 0.5
                        },
                        "scale_rel": {
                          "x": 0.5,
                          "y": 0.5
                        },
                        "bounds": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "bounds_rel": {
                          "x": 0.0,
                          "y": 0.0
                        },
                        "scale_filter": "disable",
                        "blend_method": "default",
                        "blend_type": "normal",
                        "show_transition": {
                          "duration": 300
                        },
                        "hide_transition": {
                          "duration": 300
                        },
                        "private_settings": {}
                      }
                    ]
                  },
                  "mixers": 0,
                  "sync": 0,
                  "flags": 0,
                  "volume": 1.0,
                  "balance": 0.5,
                  "enabled": true,
                  "muted": false,
                  "push-to-mute": false,
                  "push-to-mute-delay": 0,
                  "push-to-talk": false,
                  "push-to-talk-delay": 0,
                  "hotkeys": {
                    "OBSBasic.SelectScene": [],
                    "libobs.show_scene_item.1": [],
                    "libobs.hide_scene_item.1": [],
                    "libobs.show_scene_item.2": [],
                    "libobs.hide_scene_item.2": []
                  },
                  "deinterlace_mode": 0,
                  "deinterlace_field_order": 0,
                  "monitoring_type": 0,
                  "canvas_uuid": "6c69626f-6273-4c00-9d88-c5136d61696e",
                  "private_settings": {}
                }
              ],
              "groups": [],
              "scene_order": [
                {
                  "name": "Scene"
                }
              ],
              "current_scene": "Scene",
              "current_program_scene": "Scene",
              "canvases": [],
              "current_transition": "Fade",
              "transition_duration": 300,
              "transitions": [],
              "quick_transitions": [
                {
                  "name": "Cut",
                  "duration": 300,
                  "hotkeys": [],
                  "id": 1,
                  "fade_to_black": false
                },
                {
                  "name": "Fade",
                  "duration": 300,
                  "hotkeys": [],
                  "id": 2,
                  "fade_to_black": false
                },
                {
                  "name": "Fade",
                  "duration": 300,
                  "hotkeys": [],
                  "id": 3,
                  "fade_to_black": true
                }
              ],
              "saved_projectors": [],
              "preview_locked": false,
              "scaling_enabled": false,
              "scaling_level": -17,
              "scaling_off_x": 0.0,
              "scaling_off_y": 0.0,
              "modules": {
                "scripts-tool": [],
                "output-timer": {
                  "streamTimerHours": 0,
                  "streamTimerMinutes": 0,
                  "streamTimerSeconds": 30,
                  "recordTimerHours": 0,
                  "recordTimerMinutes": 0,
                  "recordTimerSeconds": 30,
                  "autoStartStreamTimer": false,
                  "autoStartRecordTimer": false,
                  "pauseRecordTimer": true
                }
              },
              "version": 2
            }
          '';
        };
      }
    );
  };

}

