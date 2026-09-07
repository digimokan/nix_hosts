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
  sec = config.sops.secrets;
  tscale = config.custom.apps.tailscale;
  zone = infra.zoneName;

in {

  config = {
    custom.system.security.enableRealTimeKit = true;

    custom.system.linuxFirmware.installPolicy = "builtins-and-proprietary";

    custom.system.networking.primaryDnsServerIpAddr = infra.lan.routerIpAddr;
    custom.system.networking.trustedIpLinkInterfaces = tscale.ipLinkInterfaces;
    custom.system.networking.useNetworkManager = true;

    custom.system.homeManager.enableForUsers = infra.allUserNames;

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.authKeyPath = sec."${zone}_zone_user_facing_tailscale_auth_key".path;

    custom.system.impermanence.persistDirs = [ "/root/nix_hosts" ];
    custom.system.impermanence.persistZrootDatasets = [
      "/home"
      "/home/${infra.primaryUser}"
    ];

    custom.users = lib.mkMerge [
      {
        root.hashedPasswordFile = sec."${zone}_zone_root_user_passhash".path;
      }

      (lib.genAttrs infra.allUserNames (u: {
        hashedPasswordFile = sec."${zone}_zone_${u}_user_passhash".path;
        extraGroups = [ config.custom.system.networking.netMgrGroup ];
      }))

      (lib.genAttrs infra.adminUserNames (u: {
        extraGroups = [ "wheel" ];
      }))
    ];
  };

}

