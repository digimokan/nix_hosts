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
    # mount /persist on early boot, so impermanence can read preserved files
    fileSystems."/persist".neededForBoot = true;

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

