{ config, lib, pkgs, inputs, ... }:

let

  cfg = config.custom.system.sops;

in {

  options.custom.system.sops = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SOPS secret management";
    };
  };

  config = lib.mkIf cfg.enable {
    # By default, use the secrets accessible to all hosts.
    sops.defaultSopsFile = ../../secrets/shared_all_hosts_secrets.yaml;
    sops.defaultSopsFormat = "yaml";

    # Tell the NixOS host exactly where to look for its private key.
    # Host will use the private key to decrypt the secrets.yaml file during the
    # boot sequence.
    sops.age.keyFile = "/var/lib/sops-nix/host_keypair.age";

    # Override the default package to use the pre-built version from the flake input
    sops.package = inputs.sops-nix.packages.${pkgs.stdenv.hostPlatform.system}.sops-install-secrets;
  };

}

