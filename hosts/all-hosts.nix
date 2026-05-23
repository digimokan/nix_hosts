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

{

  config = {
    custom.system.nixCore.enableUnifiedCli = true;
    custom.system.nixCore.enableFlakes = true;

    custom.system.sops.enable = true;

    custom.system.timezone = "US/Central";

    custom.system.tmpTmpfs.enable = true;

    custom.system.zfs.dailyAutoScrubHour = "03";
    custom.apps.sanoid.snapshottedDatasets = [ "zroot/var" ];
  };

}

