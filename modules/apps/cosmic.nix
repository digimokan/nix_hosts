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
  homeMgrUsers = config.custom.system.homeManager.enableForUsers;

in {

  options.custom.apps.cosmic = {
    enableDisplayMgr = lib.mkEnableOption "Enable the native COSMIC Greeter (Display Manager).";

    autoLoginUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Username to automatically log in via the COSMIC greeter.
        Use only with an encrypted root dataset.
      '';
    };

    enableDesktopEnvForUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users to enable COSMIC Desktop Environment for.";
    };

    userSettings = lib.mkOption {
      description = "Per-user COSMIC configurations, for overriding defaults.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          bypassInitialSetup = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Bypass the COSMIC initial setup wizard.";
          };

          panelPosition = lib.mkOption {
            type = lib.types.enum [ "Top" "Bottom" "Left" "Right" ];
            default = "Bottom";
            description = "The COSMIC panel position (anchor).";
          };

          screenOffAndLockTime = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = null;
            description = ''
              Minutes of inactivity before turning the screen off and locking it.
              Use `null` for never.
            '';
          };

          suspendOnAcPwrMinutes = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = null;
            description = ''
              Minutes of inactivity before suspending to RAM, on AC power.
              Use `null` for never.
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf (builtins.length cfg.enableDesktopEnvForUsers > 0) (lib.mkMerge [
    {
      custom.apps.cosmic.userSettings = lib.genAttrs cfg.enableDesktopEnvForUsers (u: {});
    }

    {
      custom.infrastructure.displayManager = lib.mkIf cfg.enableDisplayMgr "cosmic-greeter";
      services.displayManager.cosmic-greeter.enable = cfg.enableDisplayMgr;

      services.displayManager.autoLogin = lib.mkIf (cfg.autoLoginUser != null) {
        enable = true;
        user = cfg.autoLoginUser;
      };

      services.desktopManager.cosmic.enable = true;

      assertions = [
        {
          assertion = config.custom.system.wayland.enableXWayland;
          message = (
            "COSMIC relies heavily on Wayland and XWayland for legacy apps. "
            + "Set `custom.system.wayland.enableXWayland = true` in your "
            + "host's composition root."
          );
        }

        {
          assertion = (cfg.autoLoginUser == null) ||
            (config.custom.system.zfs.zrootPoolSchema.rootFsEncryptionMethod != "none");
          message = (
            "COSMIC auto-login is enabled for '${toString cfg.autoLoginUser}', "
            + "but zroot is unencrypted. This is a severe security risk."
          );
        }

        {
          assertion = lib.all (user: lib.elem user homeMgrUsers) cfg.enableDesktopEnvForUsers;
          message = (
            "A user configured in custom.apps.cosmic.enableDesktopEnvForUsers lacks Home Manager "
            + "enablement in custom.system.homeManager.enableForUsers."
          );
        }
      ];
    }

    {
      home-manager.users = lib.genAttrs cfg.enableDesktopEnvForUsers (userName:
        let
          userCfg = cfg.userSettings.${userName};
        in lib.mkMerge [
          (lib.mkIf userCfg.bypassInitialSetup {
            xdg.configFile."cosmic-initial-setup-done".text = "";
          })

          {
            xdg.configFile."cosmic/com.system76.CosmicPanel.Panel/v1/anchor".text =
              userCfg.panelPosition;

            xdg.configFile."cosmic/com.system76.CosmicIdle/v1/screen_off_time".text =
              if (userCfg.screenOffAndLockTime == null) then
                "None"
              else
                "Some(${toString (userCfg.screenOffAndLockTime * 60 * 1000)})";

            xdg.configFile."cosmic/com.system76.CosmicIdle/v1/suspend_on_ac_time".text =
              if (userCfg.suspendOnAcPwrMinutes == null) then
                "None"
              else
                "Some(${toString (userCfg.suspendOnAcPwrMinutes * 60 * 1000)})";
          }
        ]
      );
    }
  ]);

}

