{ config, flake, ... }: {
  # Core agenix configuration for where secrets go, and how they are read.
  age = {
    identityPaths = [ "/etc/ssh/agenix_host_ed25519_key" ];
    secretsDir = "/run/agenix";

    rekey = let
      inherit (config.networking) hostName;
      target = "nixos/${hostName}";
    in {
      # The master identity decrypted to /tmp for rekeying when,
      # agenix rekey` is run.
      masterIdentities = [ /tmp/id_age ];

      # Determines the public key for this specific machine.
      hostPubkey = let
        inherit (builtins) pathExists readFile;
        sshPub = flake + /hosts/${hostName}/agenix_host_ed25519_key.pub;
      in
        if pathExists sshPub
        then readFile sshPub
        else readFile (flake + /secrets/id_age.pub);

      storageMode = "local";
      localStorageDir = flake + /secrets/${target};
      generatedSecretsDir = flake + /secrets/${target};
    };
  };
}

