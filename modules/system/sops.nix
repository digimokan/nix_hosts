{ config, lib, pkgs, options, ... }:

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

