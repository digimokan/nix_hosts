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

  sec = config.sops.secrets;
  infra = config.custom.infrastructure;
  tscale = config.custom.apps.tailscale;
  zrootPool = import ./zroot-zpool.nix allArgs;
  zdataPool = import ./zdata-zpool.nix allArgs;

in {

  imports = [
    ./sops-secrets.nix
    ../all-hosts.nix
  ];

  config = {
    custom.system.nixCore.initialStateVersion = "25.11";

    custom.system.cpuMicrocode = "intel";

    custom.system.grub.enableMode = "efi";

    custom.system.security.enableRealTimeKit = true;

    custom.system.networking.primaryDnsServerIpAddr = infra.lan.routerIpAddr;
    custom.system.networking.trustedIpLinkInterfaces = tscale.ipLinkInterfaces;
    custom.system.networking.useNetworkManager = true;

    custom.system.zfs.zrootPoolSchema = zrootPool;
    custom.system.zfs.storagePoolSchemas = [ zdataPool ];

    custom.system.linuxFirmware.installPolicy = "builtins-and-proprietary";
    custom.system.videoChipset = "intel";

    custom.system.homeManager.enableForUsers = [ "testuser2" "digimokan" ];

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sec.cop_zone_user_facing_tailscale_auth_key.path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.system.wayland.enableXWayland = true;

    custom.apps.cosmic.enableDisplayMgr = true;
    custom.apps.cosmic.enableDesktopEnv = true;
    custom.apps.cosmic.users.testuser2 = {};

    custom.apps.pipewire.enable = true;

    custom.system.impermanence.persistDirs = [ "/root/nix_hosts" ];

    custom.users.root.hashedPasswordFile = sec.cop_zone_root_user_passhash.path;

    custom.users.digimokan.hashedPasswordFile = sec.cop_zone_digimokan_user_passhash.path;
    custom.users.digimokan.extraGroups = [ config.custom.system.networking.netMgrGroup ];

    custom.users.testuser2.hashedPasswordFile = sec.cop_zone_testuser2_user_passhash.path;
    custom.users.testuser2.extraGroups = [ config.custom.system.networking.netMgrGroup ];
  };

}

