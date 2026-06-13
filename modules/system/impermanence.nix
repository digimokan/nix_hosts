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

  cfg = config.custom.system.impermanence;
  zrootMounts = lib.mapAttrsToList (name: ds: ds.mountpoint) config.disko.devices.zpool.zroot.datasets;
  missingExplicit = lib.subtractLists cfg.persistZrootDatasets zrootMounts;
  missingDefined = lib.subtractLists zrootMounts cfg.persistZrootDatasets;

in {

  options.custom.system.impermanence = {
    persistDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of directories to bind-mount to the /persist ZFS dataset.";
    };
    persistFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of files to bind-mount to the /persist ZFS dataset.";
    };
    persistZrootDatasets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Ledger of (natively peristent) ZFS mountpoints on the zroot pool.";
    };
  };

  config = {
    # /persist: SSH key and machine-id are needed for boot
    fileSystems."/persist".neededForBoot = true;
    # /var: SOPS age key root password is needed for boot
    fileSystems."/var".neededForBoot = true;

    environment.persistence."/persist" = {
      # keep bind-mounted dirs from appearing as visible drives in file managers
      hideMounts = true;
      directories = cfg.persistDirs;
      files = cfg.persistFiles;
    };

    assertions = let
      diskoMounts = lib.mapAttrsToList (name: ds: ds.mountpoint)
        config.disko.devices.zpool.zroot.datasets;
      diskoMountsNotInLedger =
        lib.subtractLists cfg.persistZrootDatasets diskoMounts;
      ledgerMountsNotInDisko =
        lib.subtractLists diskoMounts cfg.persistZrootDatasets;
    in [
      {
        assertion = builtins.length diskoMountsNotInLedger == 0;
        message = (
          "Persistence clash: Disko defines zroot datasets mounted at "
          + "[ ${builtins.concatStringsSep " " diskoMountsNotInLedger} ] "
          + "that are NOT explicitly listed in "
          + "custom.system.impermanence.persistZrootDatasets."
        );
      }
      {
        assertion = builtins.length ledgerMountsNotInDisko == 0;
        message = (
          "Persistence clash: custom.system.impermanence.persistZrootDatasets "
          + "lists [ ${builtins.concatStringsSep " " ledgerMountsNotInDisko} ] "
          + "which are NOT defined as zroot datasets in Disko."
        );
      }
      {
        assertion = lib.all (p: !(lib.elem p cfg.persistZrootDatasets))
          (cfg.persistDirs ++ cfg.persistFiles);
        message = (
          "Persistence clash: A path cannot be both a native zroot dataset "
          + "and a bind-mounted persist dir/file."
        );
      }
    ];
  };

}

