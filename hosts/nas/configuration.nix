{ pkgs, hostSel, ... }: {
  boot.supportedFilesystems = [ "zfs" ];
  networking.hostName = hostSel.hostNameSel;
  networking.hostId = hostSel.hostIdSel;

  fileSystems."/data" = {
    device = "zdata";
    fsType = "zfs";
    options = [ "nofail" "canmount=on" ];
  };

  boot.loader.grub = {
    enable = true;
    zfsSupport = true;
    efiSupport = hostSel.isUefiSel;
    devices = hostSel.rootPoolDisksSel;
    copyKernels = true;
  };

  users.users.root.initialPassword = "nixos";
  system.stateVersion = "24.11";
}

