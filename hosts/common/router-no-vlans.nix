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

  lanNets = config.custom.infrastructure.lanNetworks;
  lanSubnet = "lan";

in {

  imports = [ ./router-base.nix ];

  config = {
    custom.infrastructure.lanNetworks.subnets = {
      "${lanSubnet}" = {
        subnetId = 1;
        subnetPrefix = "192.168.1";
      };
    };

    custom.system.nftables.trustedInterfaces = [
      lanNets.subnets.${lanSubnet}.computedInterfaceName
    ];
  };

}

