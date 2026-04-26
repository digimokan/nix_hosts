{ pkgs, hostSel, lib, ... }:
let
  zfsSpinupTimeout = 10;
in {
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostName = hostSel.hostNameSel;
  networking.hostId = hostSel.hostIdSel;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  boot.loader.systemd-boot.enable = hostSel.isUefiSel;
  boot.loader.efi.canTouchEfiVariables = hostSel.isUefiSel;

  boot.loader.grub = lib.mkIf (!hostSel.isUefiSel) {
    enable = true;
    zfsSupport = true;
    devices = [ "nodev" ];
  };

  fileSystems."/data" = {
    device = "zdata";
    fsType = "zfs";
    options = [
      "nofail"
      "canmount=on"
      "x-systemd.device-timeout=${toString zfsSpinupTimeout}s"
    ];
  };

  systemd.services."zfs-import@zdata" = {
    serviceConfig = {
      TimeoutSec = zfsSpinupTimeout;
      JobTimeoutSec = zfsSpinupTimeout;
    };
  };

  users.users.root.initialPassword = "nixos";
  system.stateVersion = "24.11";
}

