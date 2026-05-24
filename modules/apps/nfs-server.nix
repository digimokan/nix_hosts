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

  cfg = config.custom.apps.nfsServer;

  generateExports = shares:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (parentPath: shareCfg: ''
      # Parent pseudo-root
      ${parentPath} ${shareCfg.allowedClients}(rw,fsid=0,no_subtree_check)
      # Child datasets
      ${lib.concatMapStringsSep "\n" (child: "${parentPath}/${child} ${shareCfg.allowedClients}(rw,nohide,no_subtree_check)") shareCfg.childDirs}
    '') shares);

in {

  options.custom.apps.nfsServer = {
    enableVersion = lib.mkOption {
      type = lib.types.enum [ "none" "v3" "v4" ];
      default = "none";
      description = "Enable the NFS server and pin it to a specific protocol version.";
    };

    sharesToExport = lib.mkOption {
      description = "Attribute set of NFS shares. Key is the base path, value contains child dirs to export and allowed NFS clients.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          childDirs = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "List of child dirs under the base path, to export as shares.";
          };
          allowedClients = lib.mkOption {
            type = lib.types.str;
            description = "The client IP, CIDR, or '*' allowed to mount all the exported child dir shares.";
          };
        };
      });
    };
  };

  config = lib.mkIf (cfg.enableVersion != "none") {
    services.nfs.server.enable = true;
    services.nfs.server.exports = generateExports cfg.sharesToExport;

    services.nfs.settings = lib.mkMerge [
      (lib.mkIf (cfg.enableVersion == "v4") {
        nfsd = {
          udp = false;
          vers2 = false;
          vers3 = false;
          vers4 = true;
          "vers4.0" = true;
          "vers4.1" = true;
          "vers4.2" = true;
        };
      })

      (lib.mkIf (cfg.enableVersion == "v3") {
        nfsd = {
          udp = true;
          vers2 = false;
          vers3 = true;
          vers4 = false;
        };
      })
    ];
  };

}

