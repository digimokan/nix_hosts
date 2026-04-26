#!/usr/bin/env bash

set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Error: Please run this script with sudo."
  exit 1
fi

TARGET="${1:-}"

if [ -z "${TARGET}" ]; then
  echo "Error: No disk provided."
  echo "Usage: ${0} /dev/nvme0n1"
  exit 1
fi

if [ ! -b "${TARGET}" ]; then
  echo "Error: '${TARGET}' is not a valid block device."
  exit 1
fi

echo "☢️ Nuking ${TARGET}..."

swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
zfs unmount -a 2>/dev/null || true
zpool export -f -a 2>/dev/null || true
dmsetup remove_all -f 2>/dev/null || true
vgchange -an 2>/dev/null || true
mdadm --stop --scan 2>/dev/null || true

echo "Running blkdiscard..."
blkdiscard -f "${TARGET}" || echo "Warning: blkdiscard failed or is unsupported. Proceeding to software wipe..."

echo "Running wipefs..."
wipefs -a -f "${TARGET}p"* 2>/dev/null || true
wipefs -a -f "${TARGET}"

echo "Zapping partition table..."
sgdisk --zap-all "${TARGET}"

echo "Probing kernel cache..."
partprobe "${TARGET}" || echo "Warning: partprobe failed. The kernel is locked. A reboot is highly recommended."

echo "✅ Wipe sequence complete. Run 'lsblk ${TARGET}' to verify."

