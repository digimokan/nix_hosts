{ config, lib, ... }:

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
    sops.defaultSopsFile = ../../secrets/secrets.yaml;
    sops.defaultSopsFormat = "yaml";

    # path on the target machine where the private key will live
    sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

}

