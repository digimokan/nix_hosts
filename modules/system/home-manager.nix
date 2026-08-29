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

  options.custom.system.homeManager = {
    enableForUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Cumulative list of users to initialize in Home Manager on this host.";
    };
  };

  config = lib.mkIf (builtins.length config.custom.system.homeManager.enableForUsers > 0) {
    # When useGlobalPkgs and useUserPackages are both true:
    #
    # 1. Home Manager sets up path-options as read-only text files in the
    #    `/nix/store`.
    # 2. During system activation, Home Manager injects read-only symlinks
    #    relative to the user's home directory (`~/`) pointing to the store.
    # 3. The path-options:
    #      - `home.file.".mozilla"`         -> `~/.mozilla/` (dir)
    #      - `home.file.".bashrc"`          -> `~/.bashrc` (file)
    #      - `xdg.configFile."rofi"`        -> `~/.config/rofi/` (dir)
    #      - `xdg.configFile."mpd.conf"`    -> `~/.config/mpd.conf` (file)
    #      - `xdg.dataFile."yazi/scripts"`  -> `~/.local/share/yazi/scripts/` (dir)
    #      - `xdg.dataFile."ranger/bkm.md"` -> `~/.local/share/yazi/ranger/bkm.md` (file)
    #      - `xdg.stateFile."nvim"`         -> `~/.local/state/nvim` (dir)
    #      - `xdg.stateFile."sync/key.pem"` -> `~/.local/state/sync/key.pem` (file)
    # 4. Unmanaged files in path-option dirs remain untouched and mutable.
    # 5. COLLISION WARNING: If Home Manager attempts to manage a file that
    #    already exists as a standard mutable file, `just rebuild` will fail.
    #    You must manually delete the mutable file before Nix can symlink it.

    # true: use nixpkgs pinned by this repo's flake.nix nixpkgs
    # false: use nixpkgs pinned by upstream home-manager repo's flake.nix commit
    home-manager.useGlobalPkgs = true;

    # true: use nixos-rebuild switch, with pkgs at /etc/profiles/per-user/<username>
    # false: use home-manager switch, with pkgs at ~/.nix-profile
    home-manager.useUserPackages = true;

    # ignore warning: on unstable, nix and HM inputs are both on same commit
    home.enableNixpkgsReleaseCheck = false;

    home-manager.users = lib.genAttrs config.custom.system.homeManager.enableForUsers (userName: {
      home.stateVersion = config.system.stateVersion;
    });
  };

}

