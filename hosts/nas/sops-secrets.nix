/**
  Host-specific SOPS secrets configuration.
  Lists the SOPS files and the secrets to extract for this host.
*/
{
  custom.system.sops.hostSecrets = [
    {
      sopsFilePath = ../../secrets/server_host_secrets.yaml;
      secrets = {
        server_host_root_password.neededForUsers = true;
        server_host_tailscale_auth_key = {};
      };
    }
  ];
}

