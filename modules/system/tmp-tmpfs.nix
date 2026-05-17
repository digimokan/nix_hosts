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

  cfg = config.custom.system.tmpTmpfs;

in {

  options.custom.system.tmpTmpfs = {
    enable = lib.mkEnableOption "Mount /tmp as a tmpfs (RAM disk)";

    size = lib.mkOption {
      type = lib.types.str;
      default = "50%";
      description = "Maximum size of the tmpfs. Can be a percentage (e.g., '50%') or absolute (e.g., '16G').";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.tmp.useTmpfs = true;
    boot.tmp.tmpfsSize = cfg.size;
  };

}

