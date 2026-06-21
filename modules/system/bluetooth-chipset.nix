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

  cfg = config.custom.system.bluetoothChipset;
  firmwareCfg = config.custom.system.linuxFirmware;

in {

  options.custom.system.bluetoothChipset = lib.mkOption {
    type = lib.types.enum [
      "disabled"
      "realtek_rtl8852cu"
    ];
    default = "disabled";
    description = "The Bluetooth chipset in the machine to enable and use.";
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = cfg == "realtek_rtl8852cu" ->
            (firmwareCfg.installPolicy == "builtins-and-proprietary" ||
             firmwareCfg.installPolicy == "builtins-and-proprietary-with-restricted-licenses");
          message = (
            "Bluetooth chipset '${cfg}' requires proprietary firmware. "
            + "Set custom.system.linuxFirmware.installPolicy to "
            + "'builtins-and-proprietary' or 'builtins-and-proprietary-with-restricted-licenses'."
          );
        }
      ];
    }

    (lib.mkIf (cfg == "disabled") {
      boot.extraModprobeConfig = ''
        install bluetooth /bin/false
        install btusb /bin/false
      '';
    })

    (lib.mkIf (cfg != "disabled") {
      # Enables BlueZ userspace daemon and systemd services.
      # Required for ALL Bluetooth chipsets to be functional in the OS.
      hardware.bluetooth.enable = true;
    })
  ];

}

