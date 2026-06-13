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

let

  cfg = config.custom.apps.git;
  infra = config.custom.infrastructure;

in {

  options.custom.apps.git = {
    enable = lib.mkEnableOption "Enable Git version control system";

    userName = lib.mkOption {
      type = lib.types.str;
      description = "The name to use for Git commits.";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.userName}@users.noreply.github.com";
      description = "The email to use for Git commits. Defaults to the GitHub noreply standard.";
    };

    defaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "The default branch name when initializing a new repository.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      config = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
        core = {
          editor = infra.editor.defaultEditor;
          autocrlf = "input";
          safecrlf = "true";
          excludesfile = "/etc/git/ignore";
        };
        init = {
          defaultBranch = cfg.defaultBranch;
        };
        advice = {
          detachedHead = false;
        };
        alias = {
          hist = "log --pretty=format:'"
            + "%C(yellow)%h%Creset "
            + "%C(green)%ad%Creset "
            + "%s%C(auto)%d%Creset "
            + "%C(blue)[%an]%Creset' "
            + "--graph --date=short --all";
        };
        commit = {
          template = "/etc/git/commit_msg_template";
        };
      };
    };

    environment.etc."git/ignore".text = ''
      # VIM
      *.swp
      *.swo
      *.viminfo
      *~
      Session.vim
      .notags
      tags.lock
      tags.temp
      /tags
      .projections.json
    '';

    environment.etc."git/commit_msg_template".text = ''

      # EVERYTHING ABOVE THIS LINE WILL BE INCLUDED IN COMMIT MESSAGE.
      # KEY POINTS:
      #   * subject line capitalized, imperative voice, <= 50 chars, no ending period
      #   * link to github issue with "Fixes #123", "Closes #123", or "Resolves #123"
    '';
  };

}

