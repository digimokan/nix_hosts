/**
  Host-specific SOPS secrets configuration.
  Lists the SOPS files and the secrets to extract for this host.
 */
{
  custom.system.sops.hostSecrets = [
    {
      sopsFilePath = ../../secrets/user_facing_host_secrets.yaml;
      secrets = {
        user_facing_host_tailscale_auth_key = { };
      };
    }
    {
      sopsFilePath = ../../secrets/flan_user_facing_host_secrets.yaml;
      secrets = {
        flan_user_facing_host_root_password = { neededForUsers = true; };
        flan_user_facing_host_admin_password = { neededForUsers = true; };
      };
    }
    {
      sopsFilePath = ../../secrets/tm1_host_secrets.yaml;
      secrets = {
        tm1_flan_user_facing_host_testuser1_password = { neededForUsers = true; };
      };
    }
  ];
}

