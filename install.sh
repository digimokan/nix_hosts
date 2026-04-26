#!/usr/bin/env bash

set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Error: Please run this script with sudo."
  exit 1
fi

HOST="${1:-}"

if [ -z "${HOST}" ]; then
  echo "Usage: ${0} <hostname>"
  exit 1
fi

DISK_FILE="disk_ids/${HOST}.txt"

if [ ! -f "${DISK_FILE}" ]; then
  echo "Error: Disk list file '${DISK_FILE}' not found."
  exit 1
fi

mapfile -t DISKS < <(grep -v '^[[:space:]]*$' "${DISK_FILE}" || true)

if [ "${#DISKS[@]}" -eq 0 ]; then
  echo "Error: ${DISK_FILE} is empty or contains no valid disk IDs."
  exit 1
fi

DISKO_ARGS=()

for disk in "${DISKS[@]}"; do
  if [ ! -e "${disk}" ]; then
    echo "Error: Hardware target '${disk}' does not exist on this machine. Check your IDs."
    exit 1
  fi
done

if [ "${#DISKS[@]}" -eq 1 ]; then
  echo "Detected 1 disk. Configuring for single drive..."
  DISKO_ARGS+=(--disk main "${DISKS[0]}")
elif [ "${#DISKS[@]}" -eq 2 ]; then
  echo "Detected 2 disks. Configuring for mirror..."
  DISKO_ARGS+=(--disk main "${DISKS[0]}" --disk secondary "${DISKS[1]}")
else
  echo "Error: Script expects 1 or 2 disks. Found ${#DISKS[@]} in ${DISK_FILE}."
  exit 1
fi

if [ -d "/sys/firmware/efi" ]; then
  DISKO_ARGS+=(--write-efi-boot-entries)
fi

echo "Deploying configuration for host: ${HOST}"

nix --extra-experimental-features "nix-command flakes" \
  run "github:nix-community/disko#disko-install" -- \
  --flake ".#${HOST}" \
  "${DISKO_ARGS[@]}"

