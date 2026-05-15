{ config, lib, ... }:

let

  # Helper function to wire a list of secrets to a specific SOPS file
  wireSecrets = file: neededForUsers: secretNames:
    builtins.listToAttrs (map (name: {
      name = name;
      value = {
        sopsFile = file;
        inherit neededForUsers;
      };
    }) secretNames);

in {

  sops.secrets = lib.mkMerge [

    (wireSecrets ../../secrets/server_host_secrets.yaml true [
      "server_host_root_password"
      "server_host_tailscale_auth_key"
    ])

    (wireSecrets ../../secrets/shared_all_hosts_secrets.yaml true [
      "all_hosts_timezone"
    ])

  ];

}

