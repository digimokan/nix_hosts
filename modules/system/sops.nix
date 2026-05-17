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

  # Helper function to inject the file path into a set of secret definitions
  wireSecrets = file: secrets:
    lib.mapAttrs (name: opts: { sopsFile = file; } // opts) secrets;

in {

  options.custom.system.sops = {
    enable = lib.mkEnableOption "Enable SOPS secret management and default secrets";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.stable.sops ];

    # Note: the run.sh script emplaces the host key here, on deployment
    sops.age.keyFile = "/var/lib/sops-nix/host_keypair.age";

    sops.secrets = lib.mkMerge [

      (wireSecrets ../../secrets/server_host_secrets.yaml {
        server_host_root_password = { neededForUsers = true; };
        server_host_tailscale_auth_key = { };
      })

      (wireSecrets ../../secrets/shared_all_hosts_secrets.yaml {
        all_hosts_timezone = { };
      })

    ];
  };

}

