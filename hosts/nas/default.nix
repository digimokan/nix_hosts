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

{

  imports = [
    ./disko-config.nix
  ];

  config = {
    system.stateVersion = "24.05";

    custom.system.cpuMicrocode.vendor = "amd";

    custom.system.nix.enableUnifiedCli = true;
    custom.system.nix.enableFlakes = true;

    custom.system.sops.enable = true;

    custom.system.systemdBootEfi.enable = true;

    custom.system.timezone = "US/Central";

    custom.system.tmpTmpfs.enable = true;

    custom.system.networking.hostName = "nas";
    custom.system.networking.hostId = "76755dca";

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = config.sops.secrets.server_host_tailscale_auth_key.path;

    custom.system.zfs.dailyAutoScrubHour = "03";
    custom.apps.sanoid.hourlySnapshotDatasets = [ "zroot/var" ];

    custom.users.root.enable = true;
  };

}

