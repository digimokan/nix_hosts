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

  cfg = config.custom.infrastructure;
  primaries = lib.filterAttrs (_: v: v.isPrimary) cfg.usersList;
  primaryList = builtins.attrNames primaries;

in {

  options.custom.infrastructure = {
    zoneName = lib.mkOption {
      type = lib.types.str;
      description = "Security zone prefix for SOPS secrets.";
    };

    usersList = lib.mkOption {
      description = "Manifest of users deployed on this machine.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          role = lib.mkOption {
            type = lib.types.enum [ "admin" "standard" ];
            default = "standard";
          };
          isPrimary = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
      });
    };

    allUserNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Auto-generated list of all users.";
    };

    adminUserNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Auto-generated list of 'admin' role users.";
    };

    primaryUser = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = "Auto-generated string of the single primary user.";
    };
  };

  config = {
    custom.infrastructure.allUserNames = builtins.attrNames cfg.usersList;

    custom.infrastructure.adminUserNames = builtins.attrNames (
      lib.filterAttrs (_: v: v.role == "admin") cfg.usersList
    );

    custom.infrastructure.primaryUser = if (builtins.length primaryList > 0)
      then (builtins.head primaryList)
      else "";

    assertions = [
      {
        assertion = (builtins.length primaryList) == 1;
        message = "Exactly one user must be isPrimary in usersList.";
      }
    ];
  };

}

