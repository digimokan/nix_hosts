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

  cfg = config.custom.system.timezone;

in {

  options.custom.system.timezone = lib.mkOption {
    type = lib.types.str;
    default = "Etc/UTC";
    description = "The timezone of the machine (e.g., 'America/Toronto').";
  };

  config = {
    time.timeZone = cfg;
  };

}

