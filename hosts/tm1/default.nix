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

in {

  imports = [
    ./disko-config.nix
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

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sec.user_facing_host_tailscale_auth_key.path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.system.wayland.enableXWayland = true;
    custom.apps.sddm.enable = true;
    custom.apps.sddm.enableWayland = true;
    custom.apps.kdePlasmaWayland.enable = true;

    custom.apps.pipewire.enable = true;

    custom.users.root.hashedPasswordFile = sec.flan_user_facing_host_root_password.path;
    custom.users.admin.hashedPasswordFile = sec.flan_user_facing_host_admin_password.path;
    custom.users.admin.extraGroups = [ config.custom.system.networking.netMgrGroup ];
    custom.users.testuser1.hashedPasswordFile = sec.tm1_flan_user_facing_host_testuser1_password.path;
    custom.users.testuser1.extraGroups = [ config.custom.system.networking.netMgrGroup ];
  };

}

