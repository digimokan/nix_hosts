/**
  Host-specific SOPS secrets configuration.
  Lists the SOPS files and the secrets to extract for this host.
*/
{
  custom.system.sops.hostSecrets = [
    {
      sopsFilePath = ../../secrets/lsa_zone_secrets.yaml;
      secrets = {
        lsa_zone_root_user_passhash.neededForUsers = true;
        lsa_zone_server_tailscale_auth_key = {};
      };
    }
  ];
}

