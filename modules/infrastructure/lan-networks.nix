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

  cfg = config.custom.infrastructure.lanNetworks;

  subnetModule = lib.types.submodule ({ config, ... }: {
    options = {
      subnetId = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = config.vlanId;
        description = ''
          Stable positive integer ID for this subnet (used to key DHCP lease
          databases). Auto-defaults to vlanId when set; must be set explicitly
          for flat subnets (e.g., 1).
        '';
      };

      vlanId = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 4094);
        default = null;
        description = ''
          802.1Q VLAN tag (1-4094). Leave null for a flat, untagged physical
          interface.
        '';
      };

      physicalInterface = lib.mkOption {
        type = lib.types.str;
        description = ''
          Physical NIC name (e.g., "enp2s0"). Acts as the VLAN parent if
          vlanId is set, or the direct LAN interface if vlanId is null.
        '';
      };

      subnetPrefix = lib.mkOption {
        type = lib.types.str;
        description = ''
          First three octets of the /24 IPv4 subnet (e.g., "192.168.10").
        '';
      };

      dhcpPoolStartOctet = lib.mkOption {
        type = lib.types.ints.between 1 254;
        default = 100;
        description = "Starting final octet for the dynamic DHCP pool.";
      };

      dhcpPoolEndOctet = lib.mkOption {
        type = lib.types.ints.between 1 254;
        default = 200;
        description = "Ending final octet for the dynamic DHCP pool.";
      };

      dnsIpAddrsToServe = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ config.computedGatewayIpAddr ];
        description = ''
          DNS server IPs pushed to DHCP clients. Defaults to this subnet's
          gateway IP (e.g., [ "192.168.10.1" ]).
        '';
      };

      computedGatewayHostOctet = lib.mkOption {
        type = lib.types.ints.between 1 254;
        readOnly = true;
        description = ''
          Computed final IPv4 octet for the router gateway in this /24.
          e.g., 1
        '';
      };

      computedInterfaceName = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          Computed Linux interface name for this subnet.
          e.g., "vlan10" (VLAN) or "enp2s0" (flat)
        '';
      };

      computedGatewayIpAddr = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          Computed IPv4 gateway address for this subnet.
          e.g., "192.168.10.1"
        '';
      };

      computedSubnetCidr = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          Computed /24 CIDR block for this subnet.
          e.g., "192.168.10.0/24"
        '';
      };

      computedDhcpPoolRange = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = ''
          Computed dynamic DHCP pool range string for this subnet.
          e.g., "192.168.10.100 - 192.168.10.200"
        '';
      };
    };

    config = {
      computedGatewayHostOctet = 1;
      computedInterfaceName =
        if config.vlanId != null then
          "vlan${toString config.vlanId}"
        else
          config.physicalInterface;
      computedGatewayIpAddr =
        "${config.subnetPrefix}.${toString config.computedGatewayHostOctet}";
      computedSubnetCidr = "${config.subnetPrefix}.0/24";
      computedDhcpPoolRange = (
        "${config.subnetPrefix}.${toString config.dhcpPoolStartOctet}"
        + " - "
        + "${config.subnetPrefix}.${toString config.dhcpPoolEndOctet}"
      );
    };
  });

  staticReservationModule = lib.types.submodule {
    options = {
      subnet = lib.mkOption {
        type = lib.types.str;
        description = ''
          Key name of a subnet declared in
          custom.infrastructure.lanNetworks.subnets.
          e.g., "trusted", "guest", or "lan"
        '';
      };

      lastIpOctetAssignment = lib.mkOption {
        type = lib.types.ints.between 1 254;
        description = ''
          Final IPv4 octet assigned to this device in its subnet.
          e.g., 50 (resolves to "192.168.10.50" on a "192.168.10" subnet)
        '';
      };

      mac = lib.mkOption {
        type = lib.types.str;
        description = ''
          Hardware MAC address (prefer UPPER CASE).
          e.g., "AA:BB:CC:DD:EE:01"
        '';
      };

      blockWanAccess = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          If true, include this device's computed IP in computedWanBlockedIps.
        '';
      };
    };
  };

in {

  options.custom.infrastructure.lanNetworks = {
    subnets = lib.mkOption {
      type = lib.types.attrsOf subnetModule;
      default = {};
      description = "Manifest of /24 LAN/VLAN subnets managed by this router.";
    };

    staticIpReservations = lib.mkOption {
      type = lib.types.attrsOf staticReservationModule;
      default = {};
      description = "Manifest of static DHCP IP reservations and WAN egress rules.";
    };

    computedVlanConfigs = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        Computed attrset of 802.1Q VLAN definitions keyed by interface name.
        e.g., { vlan10 = { id = 10; interface = "enp2s0"; }; }
      '';
    };

    computedInterfaceIpv4Addrs = lib.mkOption {
      type = lib.types.attrs;
      readOnly = true;
      description = ''
        Computed attrset of static gateway IPv4 addresses keyed by interface.
        e.g., { vlan10 = { address = "192.168.10.1"; prefixLength = 24; }; }
      '';
    };

    computedAllInterfaceNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Computed list of all LAN/VLAN interface names across declared subnets.
        e.g., [ "vlan10" "vlan20" ] or [ "enp2s0" ]
      '';
    };

    computedGatewayIpAddrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Computed list of gateway IPv4 addresses across all declared subnets.
        e.g., [ "192.168.10.1" "192.168.20.1" ] or [ "192.168.1.1" ]
      '';
    };

    computedSubnetCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Computed list of /24 CIDR blocks across all declared subnets.
        e.g., [ "192.168.10.0/24" "192.168.20.0/24" ] or [ "192.168.1.0/24" ]
      '';
    };

    computedDhcpSubnets = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      description = ''
        Computed list of DHCPv4 subnet definitions for each declared subnet.
        e.g., [ {
          id = 10;
          subnet = "192.168.10.0/24";
          pool = "192.168.10.100 - 192.168.10.200";
          gateway = "192.168.10.1";
          dnsIpAddrsToServe = [ "192.168.10.1" ];
          staticIpAddrReservations = {
            "AA:BB:CC:DD:EE:01" = "192.168.10.50";
          };
        } ]
      '';
    };

    computedWanBlockedIps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = ''
        Computed list of static IPs where blockWanAccess = true.
        e.g., [ "192.168.10.50" "192.168.20.50" ]
      '';
    };
  };

  config = let
    subnetList = builtins.attrValues cfg.subnets;
    vlanSubnets = builtins.filter (sub: sub.vlanId != null) subnetList;
    allIfaces = builtins.map (sub: sub.computedInterfaceName) subnetList;
    allSubnetIds = builtins.map (sub: sub.subnetId) (
      builtins.filter (sub: sub.subnetId != null) subnetList
    );
    allSubnetCidrs = builtins.map (sub: sub.computedSubnetCidr) subnetList;

    resolveReservationIp = resCfg:
      let
        targetSubnet = cfg.subnets.${resCfg.subnet} or null;
        prefix =
          if targetSubnet != null then
            targetSubnet.subnetPrefix
          else
            "0.0.0";
      in "${prefix}.${toString resCfg.lastIpOctetAssignment}";

    reservationEntries = lib.mapAttrsToList (deviceName: resCfg: {
      inherit deviceName;
      inherit (resCfg) subnet lastIpOctetAssignment mac blockWanAccess;
      ipAddr = resolveReservationIp resCfg;
    }) cfg.staticIpReservations;

    allReservationMacs = builtins.map
      (entry: lib.strings.toLower entry.mac)
      reservationEntries;
    allReservationIps = builtins.map (entry: entry.ipAddr) reservationEntries;
  in {
    custom.infrastructure.lanNetworks = {
      computedVlanConfigs = builtins.listToAttrs (
        builtins.map (sub: lib.nameValuePair sub.computedInterfaceName {
          id = sub.vlanId;
          interface = sub.physicalInterface;
        }) vlanSubnets
      );

      computedInterfaceIpv4Addrs = builtins.listToAttrs (
        builtins.map (sub: lib.nameValuePair sub.computedInterfaceName {
          address = sub.computedGatewayIpAddr;
          prefixLength = 24;
        }) subnetList
      );

      computedAllInterfaceNames = allIfaces;

      computedGatewayIpAddrs =
        builtins.map (sub: sub.computedGatewayIpAddr) subnetList;

      computedSubnetCidrs =
        builtins.map (sub: sub.computedSubnetCidr) subnetList;

      computedDhcpSubnets = lib.mapAttrsToList (subnetName: sub: {
        id = if sub.subnetId != null then sub.subnetId else 1;
        subnet = sub.computedSubnetCidr;
        pool = sub.computedDhcpPoolRange;
        gateway = sub.computedGatewayIpAddr;
        dnsIpAddrsToServe = sub.dnsIpAddrsToServe;
        staticIpAddrReservations = builtins.listToAttrs (
          builtins.map (entry: lib.nameValuePair entry.mac entry.ipAddr) (
            builtins.filter (entry: entry.subnet == subnetName)
              reservationEntries
          )
        );
      }) cfg.subnets;

      computedWanBlockedIps = builtins.map (entry: entry.ipAddr) (
        builtins.filter (entry: entry.blockWanAccess) reservationEntries
      );
    };

    assertions = [
      {
        assertion = builtins.length (lib.unique allIfaces) ==
          builtins.length allIfaces;
        message = (
          "Duplicate computed interface names in "
          + "custom.infrastructure.lanNetworks.subnets. "
          + "Check for duplicate vlanId or physicalInterface entries."
        );
      }
      {
        assertion = builtins.length (lib.unique allSubnetIds) ==
          builtins.length allSubnetIds;
        message = (
          "Duplicate subnetId found in "
          + "custom.infrastructure.lanNetworks.subnets."
        );
      }
      {
        assertion = builtins.length (lib.unique allSubnetCidrs) ==
          builtins.length allSubnetCidrs;
        message = (
          "Duplicate computedSubnetCidr found in "
          + "custom.infrastructure.lanNetworks.subnets. "
          + "Check for duplicate subnetPrefix or vlanId entries."
        );
      }
      {
        assertion = builtins.length (lib.unique allReservationMacs) ==
          builtins.length allReservationMacs;
        message = (
          "Duplicate MAC address found in "
          + "custom.infrastructure.lanNetworks.staticIpReservations."
        );
      }
      {
        assertion = builtins.length (lib.unique allReservationIps) ==
          builtins.length allReservationIps;
        message = (
          "Duplicate static IPv4 address found in "
          + "custom.infrastructure.lanNetworks.staticIpReservations."
        );
      }
    ]
    ++ lib.mapAttrsToList (subnetName: sub: {
      assertion = sub.subnetId != null;
      message = (
        "Subnet '${subnetName}' in lanNetworks requires an explicit "
        + "subnetId (auto-derivation only applies when vlanId is set)."
      );
    }) cfg.subnets
    ++ lib.mapAttrsToList (subnetName: sub:
      let
        octetRegex = "(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])";
        prefixRegex = "^${octetRegex}\\.${octetRegex}\\.${octetRegex}$";
      in {
        assertion = builtins.match prefixRegex sub.subnetPrefix != null;
        message = (
          "Subnet '${subnetName}' has invalid subnetPrefix "
          + "'${sub.subnetPrefix}'. "
          + "Expected 'A.B.C' with each octet in 0-255."
        );
      }
    ) cfg.subnets
    ++ lib.mapAttrsToList (subnetName: sub: {
      assertion = sub.dhcpPoolStartOctet <= sub.dhcpPoolEndOctet;
      message = (
        "Subnet '${subnetName}' dhcpPoolStartOctet must be <= "
        + "dhcpPoolEndOctet."
      );
    }) cfg.subnets
    ++ lib.mapAttrsToList (subnetName: sub: {
      assertion =
        sub.computedGatewayHostOctet < sub.dhcpPoolStartOctet
        || sub.computedGatewayHostOctet > sub.dhcpPoolEndOctet;
      message = (
        "Subnet '${subnetName}' computedGatewayHostOctet "
        + "(${toString sub.computedGatewayHostOctet}) falls inside the "
        + "DHCP pool."
      );
    }) cfg.subnets
    ++ lib.mapAttrsToList (deviceName: resCfg: {
      assertion = builtins.hasAttr resCfg.subnet cfg.subnets;
      message = (
        "Static IP reservation '${deviceName}' references unknown subnet "
        + "'${resCfg.subnet}'."
      );
    }) cfg.staticIpReservations
    ++ lib.mapAttrsToList (deviceName: resCfg:
      let
        sub = cfg.subnets.${resCfg.subnet} or null;
      in {
        assertion = (sub != null) -> (
          resCfg.lastIpOctetAssignment != sub.computedGatewayHostOctet
          && (
            resCfg.lastIpOctetAssignment < sub.dhcpPoolStartOctet
            || resCfg.lastIpOctetAssignment > sub.dhcpPoolEndOctet
          )
        );
        message = (
          "Static IP reservation '${deviceName}' lastIpOctetAssignment "
          + "(${toString resCfg.lastIpOctetAssignment}) collides with the "
          + "gateway or dynamic DHCP pool of subnet '${resCfg.subnet}'."
        );
      }
    ) cfg.staticIpReservations;
  };

}

