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

  storagePoolName = "zdata";
  storagePoolMountPoint = "/data";

  nasCfg = config.custom.hosts.nas;

in {

  imports = [
    ./disko-config.nix
    ../all-hosts.nix
  ];

  options.custom.hosts.nas = {
    baseNfsExportDir = lib.mkOption {
      type = lib.types.str;
      default = storagePoolMountPoint;
      description = "The absolute base directory on the NAS where NFS shares originate.";
    };

    childNfsExportDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "Movies"
        "Pictures"
        "Shows"
        "HomeVideos"
        "Software"
      ];
      description = "The list of NFS share child directories.";
    };
  };

  config = {
    custom.system.nixCore.initialStateVersion = "24.05";

    custom.system.cpuMicrocode = "amd";

    custom.system.grub.enableMode = "efi";
    custom.system.grub.efiModeRemovableDisks = true;

    custom.system.networking.primaryDnsServerIpAddr = infra.lan.routerIpAddr;
    custom.system.networking.trustedIpLinkInterfaces = tscale.ipLinkInterfaces;

    custom.system.zfs.storagePools = [ storagePoolName ];

    custom.apps.tailscale.enable = true;
    custom.apps.tailscale.enableSshServer = true;
    custom.apps.tailscale.authKeyPath = sec.server_host_tailscale_auth_key.path;

    custom.apps.git.enable = true;
    custom.apps.git.userName = "digimokan";

    custom.apps.nfsServer.enableVersion = "v4";
    custom.apps.nfsServer.exports = ''
      ${nasCfg.baseNfsExportDir} ${tscale.defaultTailnetCidr}(rw,fsid=0,no_subtree_check)
      ${lib.concatMapStringsSep "\n" (dir: "${nasCfg.baseNfsExportDir}/${dir} ${tscale.defaultTailnetCidr}(rw,nohide,no_subtree_check)") nasCfg.childNfsExportDirs}
    '';

    custom.users.root.password = sec.server_host_root_password.path;
  };

}

