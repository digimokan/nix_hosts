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
      }
    );
  };

}

