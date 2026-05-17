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

  cfg = config.custom.users.root;
  sec = config.sops.secrets;

in {

  options.custom.users.root = {
    enable = lib.mkEnableOption "Enable and configure the root user account";
  };

  config = lib.mkIf cfg.enable {
    users.users.root = {
      isNormalUser = false;
      hashedPasswordFile = sec.server_host_root_password.path;
    };
  };

}

