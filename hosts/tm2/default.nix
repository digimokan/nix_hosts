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
  hdmiSoundOutput = "alsa_output.pci-0000_00_1f.3.pro-output-3";

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

    custom.system.videoChipset = "intel";

    custom.apps.pipewire.defaultSoundOutput = "alsa_output.pci-0000_00_1f.3.pro-output-3";

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.infrastructure.usersList = {
      "testuser2" = { role = "standard"; isPrimary = true; };
      "digimokan" = { role = "admin"; };
    };
  };

}

