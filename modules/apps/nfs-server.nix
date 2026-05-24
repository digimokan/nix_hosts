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

in {

  options.custom.apps.nfsServer = {
    enableVersion = lib.mkOption {
      type = lib.types.enum [ "none" "v3" "v4" ];
      default = "none";
      description = "Enable the NFS server and pin it to a specific protocol version.";
    };

    exports = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "The raw string content to populate /etc/exports.";
    };
  };

  config = lib.mkIf (cfg.enableVersion != "none") {
    services.nfs.server.enable = true;
    services.nfs.server.exports = cfg.exports;

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

