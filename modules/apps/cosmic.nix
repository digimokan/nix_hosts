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
    enableDesktopEnv = lib.mkEnableOption "Enable the COSMIC Desktop Environment";

    users = lib.mkOption {
      description = "Per-user COSMIC configurations.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          bypassInitialSetup = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Bypass the COSMIC initial setup wizard.";
          };

          panelPosition = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [ "Top" "Bottom" "Left" "Right" ]);
            default = "Bottom";
            description = "The COSMIC panel position (anchor).";
          };

          suspendOnAcPwrMinutes = lib.mkOption {
            type = lib.types.nullOr lib.types.ints.unsigned;
            default = null;
            description = "Minutes of inactivity before suspending to RAM, on AC power. Use `null` for never.";
          };
        };
      });
    };

  };

  config = lib.mkIf cfg.enableDesktopEnv (lib.mkMerge [
    {
      custom.infrastructure.displayManager = lib.mkIf cfg.enableDisplayMgr "cosmic-greeter";
      services.displayManager.cosmic-greeter.enable = cfg.enableDisplayMgr;

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
          assertion = lib.all (user: lib.elem user homeMgrUsers) (builtins.attrNames cfg.users);
          message = (
            "A user configured in custom.apps.cosmic.users lacks Home Manager "
            + "enablement in custom.system.homeManager.enableForUsers."
          );
        }
      ];
    }

    {
      home-manager.users = lib.mapAttrs (userName: userCfg: lib.mkMerge [
        (lib.mkIf userCfg.bypassInitialSetup {
          xdg.configFile."cosmic-initial-setup-done".text = "";
        })

        (lib.mkIf (userCfg.panelPosition != null) {
          xdg.configFile."cosmic/com.system76.CosmicPanel.Panel/v1/anchor".text = userCfg.panelPosition;
        })

        {
          xdg.configFile."cosmic/com.system76.CosmicIdle/v1/suspend_on_ac_time".text =
          if (userCfg.suspendOnAcPwrMinutes == null) then
            "None"
          else
            "Some(${toString (userCfg.suspendOnAcPwrMinutes * 60 * 1000)})";
        }
      ]) cfg.users;
    }
  ]);

}

