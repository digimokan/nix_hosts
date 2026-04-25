{ pkgs, myHost, ... }: {
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostName = myHost.hostname;
  networking.hostId = myHost.zfsHostId;

  fileSystems."/data" = {
    device = "zdata";
    fsType = "zfs";
    options = [ "nofail" "canmount=on" ];
  };

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = myHost.isUefi;
    devices = myHost.rootPoolDisks;
    copyKernels = true;
  };

  users.users.root.initialPassword = "nixos";
  system.stateVersion = "24.11";
}

