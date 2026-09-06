/**
  params:
    config: final, merged config tree of entire system, shared among modules
    lib: Nixpkgs library utility functions (like lib.mkIf)
    pkgs: fully configured Nixpkgs package set, based on "system"
    options: merged tree of all option _declarations_ across the system
  output (attribute set):
    zpoolSchema: see storagePools.type in zfs.nix
  allArgs: all other args passed into this function (normally ignored with ...)
 */
{ config, lib, pkgs, options, ... }@allArgs:

let

  priUser = config.custom.infrastructure.primaryUser;
  hostName = config.networking.hostName;

in {

  poolName = "zdata_${hostName}";
  disks = [
    "/dev/disk/by-id/ata-INTEL_SSDSC2BW240A4_BTDA328200CX2403GN"
  ];

  rootFsEncryptionMethod = "keyfile";
  rootFsEncryptionSopsSecretName = "${hostName}_host_zfs_zdata_encryption_symkey";

  datasets = [
    {
      name = "home";
      mountPoint = "none";
      mountsAfterZrootMount = [ "/home/${priUser}" ];
      children = [
        {
          name = "${priUser}";
          owner = "${priUser}";
          group = "users";
          children = [
            {
              name = "Desktop";
              mountPoint = "/home/${priUser}/Desktop";
              owner = "${priUser}";
              group = "users";
            }
            {
              name = "Documents";
              mountPoint = "/home/${priUser}/Documents";
              owner = "${priUser}";
              group = "users";
            }
            {
              name = "Downloads";
              mountPoint = "/home/${priUser}/Downloads";
              owner = "${priUser}";
              group = "users";
            }
            {
              name = "Music";
              mountPoint = "/home/${priUser}/Music";
              owner = "${priUser}";
              group = "users";
              recordsize = "1M";
              exec = "off";
              setuid = "off";
            }
            {
              name = "Pictures";
              mountPoint = "/home/${priUser}/Pictures";
              owner = "${priUser}";
              group = "users";
              recordsize = "1M";
              exec = "off";
              setuid = "off";
            }
            {
              name = "Public";
              mountPoint = "/home/${priUser}/Public";
              owner = "${priUser}";
              group = "users";
            }
            {
              name = "Templates";
              mountPoint = "/home/${priUser}/Templates";
              owner = "${priUser}";
              group = "users";
            }
            {
              name = "Videos";
              mountPoint = "/home/${priUser}/Videos";
              owner = "${priUser}";
              group = "users";
              recordsize = "1M";
              exec = "off";
              setuid = "off";
            }
          ];
        }
      ];
    }
  ];

}

