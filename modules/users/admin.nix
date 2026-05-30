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

  cfg = config.custom.users.admin;

in {

  options.custom.users.admin = {
    hashedPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to hashed password file. Setting this to a path adds the user to the system.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of additional groups to make user a member of.";
    };
  };

  config = lib.mkIf (cfg.hashedPasswordFile != null) {
    users.users.admin = {
      isNormalUser = true;
      extraGroups = [ "wheel" ] ++ cfg.extraGroups;
      hashedPasswordFile = cfg.hashedPasswordFile;
    };
  };

}

