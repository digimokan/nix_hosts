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
  trustedSubnet = "trusted";
  guestSubnet = "guest";

in {

  imports = [ ./router-base.nix ];

  config = {
    custom.infrastructure.zoneName = "lsa";

    custom.infrastructure.lanNetworks.subnets = {
      "${trustedSubnet}" = {
        vlanId = 10;
        subnetPrefix = "192.168.10";
      };
      "${guestSubnet}" = {
        vlanId = 20;
        subnetPrefix = "192.168.20";
      };
    };

    custom.infrastructure.lanNetworks.staticIpReservations = {
      nasBmcNic = {
        subnet = trustedSubnet;
        lastIpOctetAssignment = 50;
        mac = "90:5A:08:76:DD:B6";
        blockWanAccess = true;
      };
      studyPrinter = {
        subnet = trustedSubnet;
        lastIpOctetAssignment = 51;
        mac = "94:DD:F8:48:09:B0";
        blockWanAccess = true;
      };
      hallwayWap = {
        subnet = trustedSubnet;
        lastIpOctetAssignment = 52;
        mac = "B0:4E:26:D1:00:4A";
        blockWanAccess = true;
      };
      laundryRoomSwitch = {
        subnet = trustedSubnet;
        lastIpOctetAssignment = 53;
        mac = "D8:0D:17:41:AA:37";
        blockWanAccess = true;
      };
      livingRoomRoku = {
        subnet = guestSubnet;
        lastIpOctetAssignment = 50;
        mac = "84:EA:ED:A0:DC:DB";
        blockWanAccess = false;
      };
    };

    custom.system.nftables.trustedInterfaces = [
      lanNets.subnets.${trustedSubnet}.computedInterfaceName
    ];
    custom.system.nftables.guestInterfaces = [
      lanNets.subnets.${guestSubnet}.computedInterfaceName
    ];
  };

}

