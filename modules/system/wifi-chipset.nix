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

  cfg = config.custom.system.wifiChipset;
  firmwareCfg = config.custom.system.linuxFirmware;

in {

  options.custom.system.wifiChipset = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "disabled"
        "realtek_rtw89"
      ];
      default = "disabled";
      description = "The Wi-Fi chipset in the machine to enable and use.";
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg.backend != "disabled" -> firmwareCfg.installPolicy != "kernel-builtins";
          message = (
              "Wi-Fi chipset '${cfg.backend}' requires proprietary firmware. "
              + "Set custom.system.linuxFirmware.installPolicy to "
              + "'builtins-and-proprietary' or 'builtins-and-proprietary-with-restricted-licenses'."
          );
        }
      ];
    }

    (lib.mkIf (cfg.backend == "disabled") {
      boot.blacklistedKernelModules = [ "cfg80211" "mac80211" ];
    })
  ];

}

