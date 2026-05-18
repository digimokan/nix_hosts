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
  options.custom.infrastructure.editor = {
    defaultEditor = lib.mkOption {
      type = lib.types.str;
      default = "vi";
      description = "The global default CLI text editor command to use across the system.";
    };
  };

  config = {
    environment.variables = {
      EDITOR = config.custom.infrastructure.editor.defaultEditor;
      VISUAL = config.custom.infrastructure.editor.defaultEditor;
    };
  };
}

