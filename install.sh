#!/usr/bin/env bash

nix --extra-experimental-features "nix-command flakes" \
  run "github:nix-community/disko#disko-install" -- \
  --flake ".#nas-0" \
  --disk main "/dev/disk/by-id/nvme-KINGSTON_SNV3S500G_50026B76876DA41F" \
  "$([ -d /sys/firmware/efi ] && echo '--write-efi-boot-entries')"

