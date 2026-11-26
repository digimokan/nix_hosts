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

  cfg = config.custom.system.keaDhcpServer;
  dhcpcdInterfaces = config.custom.system.networking.enableDhcpcdForInterfaces;
  allSubnetIds = builtins.map (subnetCfg: subnetCfg.id) cfg.subnets;

in {

  options.custom.system.keaDhcpServer = {
    enableForInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Interfaces Kea listens on for DHCPv4 requests.
        Providing one or more interfaces enables the server.
      '';
    };

    subnets = lib.mkOption {
      description = "List of subnet configurations for DHCP allocation.";
      default = [];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.ints.positive;
            description = ''
              Explicit, stable positive integer ID for this subnet
              (e.g., 10 for vlan10, or 1 for a flat LAN).
            '';
          };
          subnet = lib.mkOption {
            type = lib.types.str;
            description = "CIDR subnet (e.g., '192.168.10.0/24').";
          };
          pool = lib.mkOption {
            type = lib.types.str;
            description = "Dynamic IP range (e.g., '192.168.10.100 - .200').";
          };
          gateway = lib.mkOption {
            type = lib.types.str;
            description = "Gateway IP pushed to clients.";
          };
          dnsIpAddrsToServe = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of DNS server IPs pushed to DHCP clients in this subnet.";
          };
          staticIpAddrReservations = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {};
            description = ''
              Flat mapping of MAC to IP scoped to this subnet
              (e.g., 'AA:BB:CC:DD:EE:01' = '192.168.10.50').
            '';
          };
        };
      });
    };
  };

  config = lib.mkIf (builtins.length cfg.enableForInterfaces > 0) {
    services.kea.dhcp4 = {
      enable = true;
      settings = {
        interfaces-config = {
          interfaces = cfg.enableForInterfaces;
          # Abort service startup if any listed interface cannot bind after
          # retries, rather than silently running without DHCP on that subnet.
          service-sockets-require-all = true;
          service-sockets-max-retries = 20;
          service-sockets-retry-wait-time = 500;
        };

        lease-database = {
          # Store leases in a local CSV file instead of MySQL/PostgreSQL.
          type = "memfile";
          # Flush in-memory leases to disk so they survive restarts/reboots.
          persist = true;
          name = "/var/lib/kea/dhcp4.leases";
        };
        # Total lease duration in seconds before a client must drop its IP
        # if the DHCP server is unreachable (3600s = 1 hour).
        valid-lifetime = 3600;
        # T1 timer in seconds: when a client first tries to renew its lease
        # directly with this server (1800s = 30 min, 50% of valid-lifetime).
        renew-timer = 1800;
        # T2 timer in seconds: when a client falls back to broadcast rebinding
        # if renewal failed (3150s = 52.5 min, 87.5% of valid-lifetime).
        rebind-timer = 3150;

        # Ignore top-level global reservations (prevents IPs crossing subnets).
        reservations-global = false;
        # Evaluate static MAC-to-IP reservations inside each subnet4 block.
        reservations-in-subnet = true;

        subnet4 = builtins.map (subnetCfg: {
          id = subnetCfg.id;
          subnet = subnetCfg.subnet;
          pools = [{ pool = subnetCfg.pool; }];
          option-data = [
            { name = "routers"; data = subnetCfg.gateway; }
          ] ++ lib.optional (subnetCfg.dnsIpAddrsToServe != []) {
            name = "domain-name-servers";
            data = lib.concatStringsSep ", " subnetCfg.dnsIpAddrsToServe;
          };
          reservations = lib.mapAttrsToList (mac: ip: {
            hw-address = mac;
            ip-address = ip;
          }) subnetCfg.staticIpAddrReservations;
        }) cfg.subnets;
      };
    };

    assertions = [
      {
        assertion = dhcpcdInterfaces != "all";
        message = (
          "custom.system.keaDhcpServer cannot be enabled while "
          + "custom.system.networking.enableDhcpcdForInterfaces is \"all\". "
          + "Set enableDhcpcdForInterfaces to \"none\" or explicit WAN "
          + "interface(s)."
        );
      }
      {
        assertion = (builtins.isList dhcpcdInterfaces) -> (
          lib.all
            (iface: !(lib.elem iface cfg.enableForInterfaces))
            dhcpcdInterfaces
        );
        message = (
          "An interface cannot be listed in both "
          + "custom.system.keaDhcpServer.enableForInterfaces and "
          + "custom.system.networking.enableDhcpcdForInterfaces."
        );
      }
      {
        assertion = builtins.length (lib.unique allSubnetIds) ==
          builtins.length allSubnetIds;
        message = (
          "Duplicate subnet id found in "
          + "custom.system.keaDhcpServer.subnets."
        );
      }
    ] ++ lib.concatMap (subnetCfg:
      lib.mapAttrsToList (mac: ip: {
        assertion = builtins.match
          "^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$" mac != null;
        message = (
          "Kea reservation MAC '${mac}' in subnet '${subnetCfg.subnet}' "
          + "is invalid. Must be XX:XX:XX:XX:XX:XX."
        );
      }) subnetCfg.staticIpAddrReservations
    ) cfg.subnets;
  };

}

