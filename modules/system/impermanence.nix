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

{

  config = {
    # /persist: SSH key and machine-id are needed for boot
    fileSystems."/persist".neededForBoot = true;
    # /var: SOPS age key root password is needed for boot
    fileSystems."/var".neededForBoot = true;

    environment.persistence."/persist" = {
      # keep bind-mounted dirs from appearing as visible drives in file managers
      hideMounts = true;
      directories = [
        # preserve SSH host keys
        "/etc/ssh"
        # preserve known WiFi/Network state if used
        "/etc/NetworkManager"
      ];
      files = [
        # preserve systemd journal linking
        "/etc/machine-id"
      ];
    };
  };

}

