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

  zrootPool = import ./zroot-zpool.nix allArgs;
  zdataPool = import ./zdata-zpool.nix allArgs;

in {

  imports = [
    ./sops-secrets.nix
    ../common/all-hosts.nix
    ../common/user-desktop.nix
    ../common/user-desktop-reg.nix
  ];

  config = {
    custom.system.nixCore.initialStateVersion = "25.11";

    custom.infrastructure.zoneName = "cop";

    custom.system.zfs.zrootPoolSchema = zrootPool;
    custom.system.zfs.storagePoolSchemas = [ zdataPool ];

    custom.system.cpuMicrocode = "intel";

    custom.system.grub.enableMode = "efi";

    custom.system.linuxFirmware.installPolicy = "builtins-and-proprietary";
    custom.system.videoChipset = "intel";

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.apps.cosmic.userSettings.digimokan.panelPosition = "Top";

    custom.infrastructure.usersList = {
      "testuser2" = { role = "standard"; isPrimary = true; };
      "digimokan" = { role = "admin"; };
    };
  };

}

