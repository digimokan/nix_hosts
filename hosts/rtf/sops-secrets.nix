/**
  Host-specific SOPS secrets configuration.
  Lists the SOPS files and the secrets to extract for this host.
*/
{
  custom.system.sops.hostSecrets = [
    {
      sopsFilePath = ../../secrets/cop_zone_secrets.yaml;
      secrets = {
        cop_zone_root_user_passhash = { neededForUsers = true; };
        cop_zone_server_tailscale_auth_key = {};
      };
    }
  ];
}

