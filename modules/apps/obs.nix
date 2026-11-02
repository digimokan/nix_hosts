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

          videoCanvasSize = lib.mkOption {
            type = lib.types.str;
            default = "1920x1080";
            description = "Video window canvas size, in pixels (WIDTHxHEIGHT).";
          };

          webcamDeviceId = lib.mkOption {
            type = lib.types.str;
            default = "/dev/video0";
            description = ''
              Device ID for the webcam (e.g. /dev/v4l/by-id/...).
              This is the "Device" selection in Webcam Video Capture properties.
            '';
          };

          webcamInputIndex = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = ''
              V4L2 input index. Always 0 for webcams; used for multi-port cards.
              This is the "Input" selection in Webcam Video Capture properties.
            '';
          };

          webcamResolution = lib.mkOption {
            type = lib.types.str;
            default = "1920x1080";
            description = ''
              Webcam hardware resolution WIDTHxHEIGHT).
              This is the "Resolution" selection in Webcam Video Capture properties.
            '';
          };

          webcamPixelFormat = lib.mkOption {
            type = lib.types.enum [ "MJPEG" "YUYV" "H264" "NV12" ];
            default = "MJPEG";
            description = ''
              Webcam hardware pixel format (FourCC representation).
              This is the "Video Format" selection in Webcam Video Capture properties.
            '';
          };

          desktopAudioDeviceId = lib.mkOption {
            type = lib.types.str;
            default = "default";
            description = ''
              Device ID for the desktop audio capture.
              This is the "Device" selection in Desktop Audio Capture properties.
            '';
          };

          micDeviceId = lib.mkOption {
            type = lib.types.str;
            default = "default";
            description = ''
              Device ID for the microphone or aux-input audio capture.
              This is the "Device" selection in Mic/Aux Audio Capture properties.
            '';
          };

          defaultVideoCapture = lib.mkOption {
            type = lib.types.enum [ "webcam" "screen_capture" ];
            default = "screen_capture";
            description = "Default video capture source visible on launch.";
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

        pixelFormatMap = {
          "MJPEG" = 1196444237;
          "YUYV" = 1448695129;
          "H264" = 875967048;
          "NV12" = 842094158;
        };

        # Helper to parse "WIDTHxHEIGHT" string into V4L2 required integer
        parseRes = resStr:
          let
            parts = lib.strings.splitString "x" resStr;
            w = lib.strings.toInt (builtins.elemAt parts 0);
            h = lib.strings.toInt (builtins.elemAt parts 1);
          in (w * 4294967296) + h;

        # Extract video canvas dimensions for the global resolution block
        videoCanvasDimensions = lib.strings.splitString "x" userCfg.videoCanvasSize;
        videoCanvasPixelWidth = builtins.elemAt videoCanvasDimensions 0;
        videoCanvasPixelHeight = builtins.elemAt videoCanvasDimensions 1;

        # Determine default video capture visibility booleans based on user choice
        showWebcamCapture = if userCfg.defaultVideoCapture == "webcam" then "true" else "false";
        showScreenCapture = if userCfg.defaultVideoCapture == "screen_capture" then "true" else "false";
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
                "name": "Desktop Audio Capture",
                "uuid": "8e92e09d-466f-4eaf-993b-bfec884bd039",
                "id": "pulse_output_capture",
                "settings": {
                  "device_id": "${userCfg.desktopAudioDeviceId}"
                }
              },
              "AuxAudioDevice1": {
                "name": "Mic/Aux Audio Capture",
                "uuid": "8deadf6e-78a2-4d90-8b76-36b1d3e9a8b4",
                "id": "pulse_input_capture",
                "settings": {
                  "device_id": "${userCfg.micDeviceId}"
                }
              },
              "sources": [
                {
                  "name": "Webcam Video Capture",
                  "uuid": "b7ece202-0565-4dc8-9afc-8277a9d09f7a",
                  "id": "v4l2_input",
                  "settings": {
                    "device_id": "${userCfg.webcamDeviceId}",
                    "input": ${toString userCfg.webcamInputIndex},
                    "pixelformat": ${toString pixelFormatMap.${userCfg.webcamPixelFormat}},
                    "resolution": ${toString (parseRes userCfg.webcamResolution)}
                  }
                },
                {
                  "name": "Screen Video Capture",
                  "uuid": "7367fffe-977b-4d19-bf45-533a056582b4",
                  "id": "pipewire-screen-capture-source"
                },
                {
                  "name": "MainScene",
                  "uuid": "bfb37e1f-9042-44db-9fa9-2311b8c50d83",
                  "id": "scene",
                  "settings": {
                    "id_counter": 2,
                    "custom_size": false,
                    "items": [
                      {
                        "name": "Webcam Video Capture",
                        "source_uuid": "b7ece202-0565-4dc8-9afc-8277a9d09f7a",
                        "visible": ${showWebcamCapture},
                        "id": 1
                      },
                      {
                        "name": "Screen Video Capture",
                        "source_uuid": "7367fffe-977b-4d19-bf45-533a056582b4",
                        "visible": ${showScreenCapture},
                        "id": 2
                      }
                    ]
                  }
                }
              ],
              "scene_order": [
                {
                  "name": "MainScene"
                }
              ],
              "current_scene": "MainScene",
              "current_program_scene": "MainScene",
              "resolution": {
                "x": ${videoCanvasPixelWidth},
                "y": ${videoCanvasPixelHeight}
              },
              "version": 2
            }
          '';
        };
      }
    );
  };

}

