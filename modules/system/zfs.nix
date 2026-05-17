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

  cfg = config.custom.system.zfs;

in {

  options.custom.system.zfs = {
    dailyAutoScrubHour = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The hour (e.g., '03') to perform a daily ZFS scrub. If not set, autoscrub is disabled.";
    };
  };

  config = lib.mkIf (cfg.dailyAutoScrubHour != null) {
    services.zfs.autoScrub = {
      enable = true;
      interval = "*-*-* ${cfg.dailyAutoScrubHour}:00:00";
    };
  };

}

