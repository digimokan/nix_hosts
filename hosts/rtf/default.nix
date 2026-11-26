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

  zrootPool = import ./zroot-zpool.nix allArgs;
  wanInterfaceName = "enp1s0";
  lanInterfaceName = "enp2s0";

in {

  imports = [
    ./sops-secrets.nix
    ../common/all-hosts.nix
    ../common/router-no-vlans.nix
  ];

  config = {
    custom.system.nixCore.initialStateVersion = "25.11";

    custom.infrastructure.zoneName = "cop";

    custom.system.cpuMicrocode = "intel";

    custom.system.grub.enableMode = "efi";

    custom.system.zfs.zrootPoolSchema = zrootPool;

    custom.system.networking.enableDhcpcdForInterfaces = [ wanInterfaceName ];

    custom.system.nftables.wanInterface = wanInterfaceName;

    custom.infrastructure.lanNetworks.subnets.lan.physicalInterface =
      lanInterfaceName;

    custom.infrastructure.lanNetworks.staticIpReservations = {
      mbdrPrinter = {
        subnet = "lan";
        lastIpOctetAssignment = 50;
        # TODO:
        mac = "AA:BB:CC:DD:EE:01";
        blockWanAccess = true;
      };
    };
  };

}

