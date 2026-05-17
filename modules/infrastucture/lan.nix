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

  options.custom.infrastructure.lan = {
    routerIp = lib.mkOption {
      type = lib.types.str;
      default = "172.22.22.1";
      description = "The IP address of the primary LAN router.";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "lan";
      description = "The local search domain for the LAN.";
    };
  };

}

