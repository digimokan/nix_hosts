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

  cfg = config.custom.system.nftables;

in {

  options.custom.system.nftables = {
    enableFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the custom nftables router firewall
        (networking.nftables.tables). Mutually exclusive with
        custom.system.networking.enableDefaultFirewall
        (networking.firewall.enable).
      '';
    };

    enableNat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable outbound WAN NAT masquerading in nftables.";
    };

    blockWanPrivateNetworks = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Drop unsolicited inbound packets from RFC 1918 private ranges
        (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) and CGNAT (100.64.0.0/10)
        on wanInterface. Set to false when the router is double-NATed behind
        an upstream private router (e.g., bench testing) or uses a CGNAT ISP.
        Note: Loopback (127.0.0.0/8) and link-local (169.254.0.0/16) are
        always dropped on WAN, and WAN DHCP replies (UDP 67 -> 68) plus
        established outbound connections (e.g., cable modem status pages at
        192.168.100.1) are always permitted.
      '';
    };

    wanInterface = lib.mkOption {
      type = lib.types.str;
      description = "The egress interface connected to the internet modem.";
    };

    trustedInputInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Interfaces allowed unrestricted inbound traffic to the router itself
        (chain input only, e.g., overlay VPN interfaces like tailscale0).
        Does NOT permit forwarding traffic from these interfaces to LAN or WAN.
      '';
    };

    allowedWanUdpPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [];
      description = ''
        Optional inbound UDP ports permitted on wanInterface (evaluated after
        WAN Martian filtering). Useful for direct peer-to-peer WireGuard /
        Tailscale tunnels (e.g., UDP 41641) from hard-NAT remote networks.
      '';
    };

    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Interfaces allowed to reach WAN and Guest networks.";
    };

    guestInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Interfaces allowed to reach WAN, blocked from Trusted.";
    };

    egressFilteredIps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Specific LAN IPv4 addresses strictly blocked from reaching the WAN
        and from querying router DNS (TCP/UDP 53, preventing DNS tunneling
        through Unbound). DHCP (UDP 67) and local LAN traffic remain allowed.
      '';
    };
  };

  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(
            cfg.enableFirewall
            && config.custom.system.networking.enableDefaultFirewall
          );
          message = (
            "The options custom.system.nftables.enableFirewall and "
            + "custom.system.networking.enableDefaultFirewall are mutually "
            + "exclusive and cannot be enabled at the same time."
          );
        }
        {
          assertion = cfg.enableNat -> cfg.enableFirewall;
          message = (
            "custom.system.nftables.enableNat requires "
            + "custom.system.nftables.enableFirewall to be enabled."
          );
        }
        {
          assertion = cfg.enableNat ->
            config.custom.system.networking.enableIpv4Forwarding;
          message = (
            "custom.system.nftables.enableNat requires "
            + "custom.system.networking.enableIpv4Forwarding to be enabled."
          );
        }
      ];
    }

    (lib.mkIf cfg.enableFirewall (
      let
        hasTrustedInput = builtins.length cfg.trustedInputInterfaces > 0;
        hasWanUdpPorts = builtins.length cfg.allowedWanUdpPorts > 0;
        hasTrust = builtins.length cfg.trustedInterfaces > 0;
        hasGuest = builtins.length cfg.guestInterfaces > 0;
        hasFiltered = builtins.length cfg.egressFilteredIps > 0;

        quoteStr = s: "\"${s}\"";
        trustedInputSet = "{ ${
          lib.concatMapStringsSep ", " quoteStr cfg.trustedInputInterfaces
        } }";
        wanUdpPortSet = "{ ${
          lib.concatMapStringsSep ", " toString cfg.allowedWanUdpPorts
        } }";
        trustSet = "{ ${
          lib.concatMapStringsSep ", " quoteStr cfg.trustedInterfaces
        } }";
        guestSet = "{ ${
          lib.concatMapStringsSep ", " quoteStr cfg.guestInterfaces
        } }";
        filteredSet = "{ ${lib.concatStringsSep ", " cfg.egressFilteredIps} }";

        wanMartians =
          [
            "127.0.0.0/8"
            "169.254.0.0/16"
          ]
          ++ lib.optionals cfg.blockWanPrivateNetworks [
            "10.0.0.0/8"
            "172.16.0.0/12"
            "192.168.0.0/16"
            "100.64.0.0/10"
          ];
        wanMartiansSet = lib.concatStringsSep ",\n    " wanMartians;
      in {
        assertions = [
          {
            assertion = !(lib.elem cfg.wanInterface cfg.trustedInputInterfaces);
            message = (
              "custom.system.nftables.wanInterface ('${cfg.wanInterface}') "
              + "cannot be listed in "
              + "custom.system.nftables.trustedInputInterfaces."
            );
          }
        ];

        networking.nftables = {
          enable = true;
          # When true, NixOS prepends "flush ruleset" to the nft script run
          # whenever nftables.service starts (boot) or reloads (nixos-rebuild /
          # just rebuild), wiping every table in the kernel, including runtime
          # tables created by other daemons (e.g., tailscaled).
          # When false, NixOS atomically deletes and recreates only the tables
          # declared below on each start/reload, leaving other tables intact.
          flushRuleset = false;

          tables = {
            # Custom packet-filtering table for this router (accept/drop rules
            # for both router-destined traffic and traffic routed between
            # interfaces). The name "nix_router_filter" is an arbitrary custom
            # label, namespaced so reloads never collide with daemon-managed
            # tables (such as tailscaled's own netfilter tables).
            nix_router_filter = {
              # Address family "inet" covers BOTH IPv4 and IPv6 in one table
              # (unlike "ip" = IPv4-only or "ip6" = IPv6-only). Even with IPv6
              # disabled on routers, "inet" + "policy drop" drops any stray
              # IPv6 frames instead of letting them bypass an IPv4-only table.
              family = "inet";
              content = ''
                # Define table-scoped named sets (reusable lookup variables
                # referenced in rules below with "@<name>"):
                # - type: data type stored (ipv4_addr = IPv4 IP/CIDR,
                #   ifname = network interface name string).
                # - flags interval: enables matching CIDR ranges/subnets
                #   (e.g., 10.0.0.0/8) instead of only single discrete IPs.
                # - elements: the actual list of values loaded into the set.
                set wan_martians {
                  type ipv4_addr;
                  flags interval;
                  elements = {
                    ${wanMartiansSet}
                  }
                }
                ${lib.optionalString hasTrustedInput ''
                  set trusted_input_ifs {
                    type ifname;
                    elements = ${trustedInputSet}
                  }
                ''}
                ${lib.optionalString hasTrust ''
                  set trusted_ifs {
                    type ifname;
                    elements = ${trustSet}
                  }
                ''}
                ${lib.optionalString hasGuest ''
                  set guest_ifs {
                    type ifname;
                    elements = ${guestSet}
                  }
                ''}
                ${lib.optionalString hasFiltered ''
                  set egress_filtered {
                    type ipv4_addr;
                    elements = ${filteredSet}
                  }
                ''}

                # Handles packets whose final destination is this router host
                # itself (e.g., LAN DNS/DHCP requests, WAN DHCP renewals,
                # Tailscale SSH). Does NOT apply to routed transit traffic.
                chain input {
                  # type filter: evaluate accept/drop firewall verdicts.
                  # hook input: attach to the kernel's local-delivery hook.
                  # priority 0: standard filter priority (lower runs earlier).
                  # policy drop: default-deny anything not explicitly accepted.
                  type filter hook input priority 0; policy drop;
                  iifname "lo" accept \
                    comment "Allow all loopback traffic"
                  ct state { established, related } accept \
                    comment "Allow established and related traffic"
                  ct state invalid drop \
                    comment "Drop invalid connection-tracking packets"
                  ${lib.optionalString hasTrustedInput (
                    "iifname @trusted_input_ifs accept "
                    + ''comment "Allow inbound management on trusted overlays"''
                  )}
                  iifname "${cfg.wanInterface}" \
                    udp sport 67 udp dport 68 accept \
                    comment "Allow WAN DHCP client replies before Martian drop"
                  iifname "${cfg.wanInterface}" ip saddr @wan_martians drop \
                    comment "Drop spoofed Martian source IPs on WAN"
                  ${lib.optionalString hasWanUdpPorts (
                    "iifname \"${cfg.wanInterface}\" udp dport "
                    + "${wanUdpPortSet} accept "
                    + ''comment "Allow configured inbound WAN UDP ports"''
                  )}

                  ${lib.optionalString hasFiltered (
                    "ip saddr @egress_filtered meta l4proto { tcp, udp } "
                    + "th dport 53 drop "
                    + ''comment "Block router DNS from WAN-filtered IPs"''
                  )}
                  ${lib.optionalString hasTrust (
                    "iifname @trusted_ifs meta l4proto { tcp, udp } "
                    + "th dport 53 accept "
                    + ''comment "Allow DNS (UDP/TCP) from Trusted LAN"''
                  )}
                  ${lib.optionalString hasTrust (
                    "iifname @trusted_ifs udp dport 67 accept "
                    + ''comment "Allow DHCP from Trusted LAN"''
                  )}
                  ${lib.optionalString hasTrust (
                    "iifname @trusted_ifs icmp type echo-request accept "
                    + ''comment "Allow ICMP ping from Trusted LAN"''
                  )}
                  ${lib.optionalString hasGuest (
                    "iifname @guest_ifs meta l4proto { tcp, udp } "
                    + "th dport 53 accept "
                    + ''comment "Allow DNS (UDP/TCP) from Guest LAN"''
                  )}
                  ${lib.optionalString hasGuest (
                    "iifname @guest_ifs udp dport 67 accept "
                    + ''comment "Allow DHCP from Guest LAN"''
                  )}
                  ${lib.optionalString hasGuest (
                    "iifname @guest_ifs icmp type echo-request "
                    + "limit rate 10/second burst 20 packets accept "
                    + ''comment "Allow rate-limited ICMP ping from Guest LAN"''
                  )}
                }

                # Handles transit packets routed THROUGH this router between
                # interfaces (e.g., LAN -> WAN, Trusted -> Guest, and return
                # WAN -> LAN traffic). Does NOT apply to router-local I/O.
                chain forward {
                  # type filter: evaluate accept/drop firewall verdicts.
                  # hook forward: attach to the kernel's routed-transit hook.
                  # priority 0: standard filter priority (lower runs earlier).
                  # policy drop: default-deny all inter-interface forwarding.
                  type filter hook forward priority 0; policy drop;
                  ct state { established, related } accept \
                    comment "Allow established and related traffic"
                  ct state invalid drop \
                    comment "Drop invalid connection-tracking packets"
                  iifname "${cfg.wanInterface}" ip saddr @wan_martians drop \
                    comment "Drop spoofed Martian source IPs on WAN"

                  ${lib.optionalString hasFiltered (
                    "ip saddr @egress_filtered "
                    + "oifname \"${cfg.wanInterface}\" drop "
                    + ''comment "Block filtered LAN IPs from reaching WAN"''
                  )}
                  ${lib.optionalString (hasTrust && hasGuest) (
                    "iifname @trusted_ifs oifname @guest_ifs accept "
                    + ''comment "Allow Trusted LAN to reach Guest LAN"''
                  )}
                  ${lib.optionalString hasTrust (
                    "iifname @trusted_ifs "
                    + "oifname \"${cfg.wanInterface}\" accept "
                    + ''comment "Allow Trusted LAN to reach WAN"''
                  )}
                  ${lib.optionalString hasGuest (
                    "iifname @guest_ifs "
                    + "oifname \"${cfg.wanInterface}\" accept "
                    + ''comment "Allow Guest LAN to reach WAN"''
                  )}
                }
              '';
            };

            # Custom Network Address Translation table for outbound internet
            # traffic. The name "nix_router_nat" is an arbitrary custom label
            # so it never collides with tailscaled's "table ip nat", and is
            # toggled cleanly by cfg.enableNat.
            nix_router_nat = {
              enable = cfg.enableNat;
              # Address family "ip" is IPv4-only (NAT masquerading applies only
              # to IPv4 here).
              family = "ip";
              content = ''
                # Runs after routing decisions and filter chains, right before
                # packets exit the outbound interface, allowing source-IP NAT.
                chain postrouting {
                  # type nat: enables NAT translation (masquerade/SNAT/DNAT).
                  # hook postrouting: final Netfilter hook before packet egress.
                  # priority 100: standard SNAT priority (runs after filter).
                  # policy accept: pass non-NAT packets through unmodified
                  # (traffic blocking is already enforced by nix_router_filter).
                  type nat hook postrouting priority 100; policy accept;
                  # For packets leaving out the WAN interface (oifname), replace
                  # the private LAN source IP (e.g., 192.168.10.x, which cannot
                  # be routed on the internet) with whatever public IP is
                  # currently assigned to WAN via DHCP. Conntrack automatically
                  # translates return packets back to the original LAN host.
                  oifname "${cfg.wanInterface}" masquerade \
                    comment "Masquerade LAN source IPs to WAN IP (SNAT)"
                }
              '';
            };
          };
        };
      }
    ))
  ];

}

