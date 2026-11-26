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

  infra = config.custom.infrastructure;
  lanNets = infra.lanNetworks;
  sec = config.sops.secrets;
  tscale = config.custom.apps.tailscale;
  zone = infra.zoneName;

in {

  config = {
    custom.system.networking.enableDefaultFirewall = false;
    custom.system.networking.enableIpv6 = false;
    custom.system.networking.enableIpv4Forwarding = true;
    # Point the router itself at its local Unbound DNS resolver (IPv4 loopback).
    custom.system.networking.primaryDnsServerIpAddr = "127.0.0.1";
    custom.system.networking.vlans = lanNets.computedVlanConfigs;
    custom.system.networking.staticInterfaceIpv4Addrs = lanNets.computedInterfaceIpv4Addrs;

    custom.system.unboundDnsResolver.enable = true;
    custom.system.unboundDnsResolver.listenIpAddrs =
      [ "127.0.0.1" ] ++ lanNets.computedGatewayIpAddrs;
    custom.system.unboundDnsResolver.allowedClientCidrs = lanNets.computedSubnetCidrs;

    custom.system.nftables.enableFirewall = true;
    custom.system.nftables.enableNat = true;
    custom.system.nftables.trustedInputInterfaces = tscale.ipLinkInterfaces;
    custom.system.nftables.allowedWanUdpPorts = [ tscale.udpPort ];
    custom.system.nftables.egressFilteredIps = lanNets.computedWanBlockedIps;

    custom.system.keaDhcpServer.enableForInterfaces = lanNets.computedAllInterfaceNames;
    custom.system.keaDhcpServer.subnets = lanNets.computedDhcpSubnets;

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.acceptDns = false;
    custom.apps.tailscale.authKeyPath = sec."${zone}_zone_server_tailscale_auth_key".path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.system.impermanence.persistDirs = [ "/root/nix_hosts" ];

    custom.users.root.hashedPasswordFile = sec."${zone}_zone_root_user_passhash".path;
  };

}

