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

in {

  imports = [
    ./disko-config.nix
    ../all-hosts.nix
  ];

  config = {
    custom.system.nixCore.initialStateVersion = "24.05";

    custom.system.cpuMicrocode = "amd";

    custom.system.grub.enableMode = "efi";
    custom.system.grub.efiModeRemovableDisks = true;

    custom.system.networking.hostName = "nas";
    custom.system.networking.hostId = "76755dca";
    custom.system.networking.primaryDnsServerIpAddr = infra.lan.routerIpAddr;

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sec.server_host_tailscale_auth_key.path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.users.root.password = sec.server_host_root_password.path;
  };

}

