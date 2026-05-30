/**
  params:
    lib: Nixpkgs library utility functions (like lib.mkIf)
  output (attribute set):
    an attribute set of disk(s) and filesystem(s) parsable by disko
*/
{ lib, ... }:

let
  genDiskoLayout = import ../../disko/layout-generator.nix { inherit lib; };
in
  genDiskoLayout
    { enableEncryption = true; }
    [
      "/dev/disk/by-id/wwn-0xXXXXXXXXXXXXXXXX"
    ]

