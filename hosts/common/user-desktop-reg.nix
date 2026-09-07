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

in {

  config = {
    custom.apps.tailscale.enableSshServer = true;

    custom.system.wayland.enableXWayland = true;

    custom.apps.cosmic.enableDisplayMgr = true;
    custom.apps.cosmic.autoLoginUser = infra.primaryUser;
    custom.apps.cosmic.enableDesktopEnvForUsers = infra.allUserNames;

    custom.apps.pipewire.enable = true;
  };

}

