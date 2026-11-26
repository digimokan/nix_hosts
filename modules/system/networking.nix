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

  cfg = config.custom.system.networking;
  dhcpcdIsList = builtins.isList cfg.enableDhcpcdForInterfaces;

in {

  options.custom.system.networking = {
    useNetworkManager = lib.mkEnableOption (
      "Whether to use NetworkManager "
      + "(typically true for desktops, false for servers)."
    );

    enableDhcpcdForInterfaces = lib.mkOption {
      type = lib.types.either
        (lib.types.enum [ "all" "none" ])
        (lib.types.nonEmptyListOf lib.types.str);
      default = "all";
      description = ''
        Interfaces to run the dhcpcd client on: "all", "none", or a
        non-empty list of interface names (e.g., [ "enp1s0" ]). Must be
        "none" when useNetworkManager is enabled.
      '';
    };

    enableDefaultFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable the default NixOS simple stateful firewall
        (networking.firewall.enable). Mutually exclusive with
        custom.system.nftables.enableFirewall (networking.nftables.tables).
      '';
    };

    enableIpv6 = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable IPv6 at the OS networking layer (networking.enableIPv6).
        When true, this enables:
        - Kernel IPv6 stack and interface addressing (loopback ::1, link-local
          fe80::, and SLAAC / Router Advertisements).
        - IPv6 handling in dhcpcd (DHCPv6 and Router Solicitations).
        - IPv6 rule generation in the default NixOS firewall (ip6tables).
        - IPv6 support across NixOS networking services that honor
          networking.enableIPv6.
        Note: On routers, this does NOT enable IPv6 forwarding, DHCPv6/RA
        server advertisements, or IPv6 rules in custom.system.nftables.
      '';
    };

    enableIpv4Forwarding = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable IPv4 packet forwarding and router-grade kernel network
        hardening via boot.kernel.sysctl (for router hosts only).
        When true, this configures:
        - net.ipv4.ip_forward = 1 (routes IPv4 packets between interfaces).
        - net.ipv4.conf.{all,default}.rp_filter = 1 (strict RFC 3704 reverse
          path filtering to drop spoofed source IPs).
        - net.ipv4.conf.{all,default}.{accept,secure}_redirects = 0 (ignores
          incoming ICMP redirects that could alter routing tables).
        - net.ipv4.conf.{all,default}.send_redirects = 0 (disables sending
          ICMP redirects when forwarding packets).
        Note: Strict rp_filter = 1 assumes symmetric routing (single WAN);
        do not enable this on a host acting as a Tailscale exit-node client.
      '';
    };

    primaryDnsServerIpAddr = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The IP address of the primary DNS server.
        If set, this forces the system to use it.
      '';
    };

    trustedIpLinkInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Network interfaces that bypass the firewall (fully trusted).
      '';
    };

    vlans = lib.mkOption {
      description = "Declarative mapping of VLAN IDs to physical ports.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.int;
            description = "The 802.1Q VLAN tag.";
          };
          interface = lib.mkOption {
            type = lib.types.str;
            description = "The physical host interface.";
          };
        };
      });
    };

    staticInterfaceIpv4Addrs = lib.mkOption {
      description = "Static IPv4 address assignments keyed by interface name.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          address = lib.mkOption {
            type = lib.types.str;
            description = "Static IPv4 address for the interface.";
          };
          prefixLength = lib.mkOption {
            type = lib.types.ints.between 0 32;
            default = 24;
            description = "CIDR prefix length for the interface.";
          };
        };
      });
    };

    netMgrGroup = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        The NetworkManager group name.
        Only exported if NetworkManager is enabled.
      '';
    };

    persistConfigDir = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        The directory containing state to persist.
        Only exported if NetworkManager is enabled.
      '';
    };
  };

  config = let
    vlanParentIfaces = lib.unique (
      builtins.map (vlanCfg: vlanCfg.interface) (builtins.attrValues cfg.vlans)
    );
  in lib.mkMerge [
    {
      networking.networkmanager.enable = cfg.useNetworkManager;
      networking.useDHCP = cfg.enableDhcpcdForInterfaces == "all";
      networking.firewall.enable = cfg.enableDefaultFirewall;
      networking.enableIPv6 = cfg.enableIpv6;
      networking.firewall.trustedInterfaces = cfg.trustedIpLinkInterfaces;
      networking.vlans = cfg.vlans;
      networking.nameservers =
        lib.mkIf (cfg.primaryDnsServerIpAddr != null) [
          cfg.primaryDnsServerIpAddr
        ];
      networking.dhcpcd.extraConfig = lib.mkIf (
        cfg.primaryDnsServerIpAddr != null
        && cfg.enableDhcpcdForInterfaces != "none"
      ) "nohook resolv.conf";
      networking.hostId = lib.mkDefault (
        builtins.substring 0 8 (
          builtins.hashString "sha256" config.networking.hostName
        )
      );

      assertions = [
        {
          assertion = cfg.useNetworkManager ->
            (cfg.enableDhcpcdForInterfaces == "none");
          message = (
            "custom.system.networking.useNetworkManager conflicts with "
            + "dhcpcd. Set "
            + "custom.system.networking.enableDhcpcdForInterfaces = \"none\"."
          );
        }
        {
          assertion = (cfg.staticInterfaceIpv4Addrs != {}) ->
            (cfg.enableDhcpcdForInterfaces != "all");
          message = (
            "custom.system.networking.staticInterfaceIpv4Addrs cannot be used "
            + "while enableDhcpcdForInterfaces is \"all\". Set "
            + "enableDhcpcdForInterfaces to \"none\" or explicit interface(s)."
          );
        }
        {
          assertion = dhcpcdIsList -> (
            lib.all
              (iface: !(builtins.hasAttr iface cfg.staticInterfaceIpv4Addrs))
              cfg.enableDhcpcdForInterfaces
          );
          message = (
            "An interface cannot be configured in both "
            + "custom.system.networking.staticInterfaceIpv4Addrs and "
            + "custom.system.networking.enableDhcpcdForInterfaces."
          );
        }
        {
          assertion = (vlanParentIfaces != []) ->
            (cfg.enableDhcpcdForInterfaces != "all");
          message = (
            "custom.system.networking.vlans cannot be used while "
            + "enableDhcpcdForInterfaces is \"all\". Set "
            + "enableDhcpcdForInterfaces to \"none\" or explicit interface(s)."
          );
        }
        {
          assertion = dhcpcdIsList -> (
            lib.all
              (iface: !(lib.elem iface vlanParentIfaces))
              cfg.enableDhcpcdForInterfaces
          );
          message = (
            "A VLAN parent interface in custom.system.networking.vlans cannot "
            + "also be listed in "
            + "custom.system.networking.enableDhcpcdForInterfaces."
          );
        }
      ];
    }

    (lib.mkIf cfg.enableIpv4Forwarding {
      boot.kernel.sysctl = {
        # Allow the kernel to route IPv4 packets between interfaces.
        "net.ipv4.ip_forward" = 1;

        # Strict Reverse Path Filtering (RFC 3704): drop incoming packets whose
        # source IP would not route back out the same interface (anti-spoofing).
        "net.ipv4.conf.all.rp_filter" = 1;
        "net.ipv4.conf.default.rp_filter" = 1;

        # Ignore incoming ICMP redirects so peers cannot alter routing tables.
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.secure_redirects" = 0;
        "net.ipv4.conf.default.secure_redirects" = 0;

        # Do not send ICMP redirects when forwarding between interfaces.
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
      };
    })

    (lib.mkIf dhcpcdIsList {
      networking.interfaces = lib.genAttrs cfg.enableDhcpcdForInterfaces (
        _: { useDHCP = true; }
      );
    })

    (lib.mkIf (vlanParentIfaces != []) {
      # Ensure NixOS scripted networking brings VLAN parent trunk interfaces
      # administratively UP even when they carry no untagged IP address.
      networking.interfaces = lib.genAttrs vlanParentIfaces (_: {});
    })

    (lib.mkIf (cfg.staticInterfaceIpv4Addrs != {}) {
      networking.interfaces = lib.mapAttrs (_: addrCfg: {
        ipv4.addresses = [
          {
            address = addrCfg.address;
            prefixLength = addrCfg.prefixLength;
          }
        ];
      }) cfg.staticInterfaceIpv4Addrs;
    })

    (lib.mkIf cfg.useNetworkManager {
      custom.system.networking.netMgrGroup = "networkmanager";
      custom.system.networking.persistConfigDir = "/etc/NetworkManager";
    })
  ];

}

