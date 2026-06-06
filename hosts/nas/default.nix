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
  nasCfg = config.custom.hosts.nas;

  # storagePoolName = "zdata";

  storagePoolName = "zdata_nas";
  storagePoolBaseDataset = "data";
  storagePoolBaseMountDir = "/data";
  storagePoolChildDirs = [
    "Movies"
    "Pictures"
    "Shows"
    "HomeVideos"
    "Software"
  ];

in {

  imports = [
    ./disko-config.nix
    ../all-hosts.nix
  ];

  options.custom.hosts.nas = {
    nfsChildExportDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "The list of child dirs to export. Exposed for client awareness.";
    };
  };

  config = {
    custom.system.sops.hostSecrets = [
      {
        sopsFilePath = ../../secrets/server_host_secrets.yaml;
        secrets = {
          server_host_root_password.neededForUsers = true;
          server_host_tailscale_auth_key = {};
        };
      }
    ];

    custom.system.nixCore.initialStateVersion = "24.05";

    custom.infrastructure.hostType = "server";

    custom.system.cpuMicrocode = "amd";

    custom.system.grub.enableMode = "efi";
    custom.system.grub.efiModeRemovableDisks = true;

    custom.system.networking.primaryDnsServerIpAddr = infra.lan.routerIpAddr;
    custom.system.networking.trustedIpLinkInterfaces = tscale.ipLinkInterfaces;

    custom.system.zfs.storagePools = [
      {
        poolName = storagePoolName;
        datasets = [
          {
            baseDataset = storagePoolBaseDataset;
            mountPoint = storagePoolBaseMountDir;
            childDatasets = storagePoolChildDirs;
          }
        ];
      }
    ];

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sec.server_host_tailscale_auth_key.path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.hosts.nas.nfsChildExportDirs = storagePoolChildDirs;

    custom.apps.nfsServer.enableVersion = "v4";
    custom.apps.nfsServer.sharesToExport = {
      "${storagePoolBaseMountDir}" = {
        allowedClients = tscale.defaultTailnetCidr;
        childDirs = nasCfg.nfsChildExportDirs;
      };
    };

    custom.users.root.hashedPasswordFile = sec.server_host_root_password.path;
  };

}

