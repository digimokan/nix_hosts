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

  cfg = config.custom.system.sops;

in {

  options.custom.system.sops = {
    enable = lib.mkEnableOption "Enable SOPS secret management and default secrets";

    hostSecrets = lib.mkOption {
      description = "List of SOPS files and the secrets to extract from them for this host.";
      default = [];
      type = lib.types.listOf (lib.types.submodule {
        options = {
          sopsFilePath = lib.mkOption {
            type = lib.types.path;
            description = "Path to the encrypted SOPS YAML file.";
          };
          secrets = lib.mkOption {
            type = lib.types.attrs;
            default = {};
            description = "Attribute set of secrets to map to this file (e.g., { my_secret = { neededForUsers = true; }; }).";
          };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.sops ];

    sops.age.keyFile = "/var/lib/sops-nix/host_keypair.age";

    sops.secrets = lib.mkMerge (
      builtins.map (entry:
        lib.mapAttrs (name: opts: { sopsFile = entry.sopsFilePath; } // opts) entry.secrets
      ) cfg.hostSecrets
    );
  };

}

