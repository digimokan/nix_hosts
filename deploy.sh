#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
DEFAULT_REPO_URL="https://github.com/your-username/your-repo.git"

# --- Globals ---
TARGET_HOST=""
REMOTE_IP=""
DEPLOY_MODE="local"
REPO_URL="${DEFAULT_REPO_URL}"
WIPE_DISKS="no"
REBOOT_REMOTE="yes"

# --- Utility Functions ---

die() {
  printf "Error: %s\n" "${1}" >&2
  exit 1
}

print_usage() {
  cat <<EOF
USAGE: $(basename "${0}") [OPTIONS]

PURPOSE:
  * Format disks and deploy a NixOS configuration to a target machine.
  * The target machine is running the NixOS minimal installer image, and SSH.
  * For remote deployment, the orchestrating machine need not be running NixOS.

OPTIONS:
  -t, --target HOST      (Required) The NixOS configuration name (e.g., nas-0)
  -r, --remote IP        (Optional) Deploy remotely to the target IP address
  -u, --url URL          (Optional) Git repository URL to clone on remote target
                         Default: ${DEFAULT_REPO_URL}
  -w, --wipe-disks       (Optional) Aggressively nuke old partitions, ZFS metadata, and labels
                         SAFETY: Only executes if running from the NixOS Live ISO overlay.
  --no-reboot-remote     (Optional) Do NOT reboot the remote machine after deployment
  -h, --help             Show this help menu and exit

EXAMPLES:
  Local Deploy:  sudo ./$(basename "${0}") -t nas-0 -w
  Remote Deploy: ./$(basename "${0}") -t nas-0 -r 192.168.1.50 -w
EOF
}

parse_args() {
  while [ "${#}" -gt 0 ]; do
    local flag="${1}"
    case "${flag}" in
      -h|--help)
        print_usage
        exit 0
        ;;
      -w|--wipe-disks)
        WIPE_DISKS="yes"
        shift
        ;;
      --no-reboot-remote)
        REBOOT_REMOTE="no"
        shift
        ;;
      -t|--target|-r|--remote|-u|--url)
        shift
        if [ "${#}" -eq 0 ] || [ "${1:0:1}" = "-" ]; then
          die "Argument for ${flag} is missing."
        fi

        local val="${1}"
        case "${flag}" in
          -t|--target) TARGET_HOST="${val}" ;;
          -r|--remote) REMOTE_IP="${val}"; DEPLOY_MODE="remote" ;;
          -u|--url)    REPO_URL="${val}" ;;
        esac
        shift
        ;;
      -*)
        die "Unsupported option '${flag}'."
        ;;
      *)
        die "Unexpected argument '${flag}'."
        ;;
    esac
  done

  if [ -z "${TARGET_HOST}" ]; then
    die "The --target option is required. Use -h for help."
  fi
}

wipe_target_disks() {
  local target_disks=("${@}")

  echo "🛡️ Validating safety constraints for disk wipe..."

  if [ "$(uname -s)" != "Linux" ]; then
    die "Safety abort: Disks can only be wiped on a Linux system."
  fi

  if ! df -T / | grep -q 'overlay'; then
    die "Safety abort: Root filesystem is not 'overlay'. You do not appear to be running the NixOS Live ISO."
  fi

  echo ""
  echo "⚠️  WARNING: You are about to DESTROY ALL DATA on the following disks:"
  for disk in "${target_disks[@]}"; do
    echo "   -> ${disk}"
  done
  echo ""

  if [ -t 0 ]; then
    read -r -p "Type 'WIPE' in all caps to confirm destruction: " confirm_wipe
    if [ "${confirm_wipe}" != "WIPE" ]; then
      die "Wipe aborted by user."
    fi
  else
    echo "SSH Session detected. Proceeding with wipe automatically based on -w flag."
  fi

  echo "🧹 Tearing down active mounts and volumes system-wide..."
  swapoff -a 2>/dev/null || true
  umount -R /mnt 2>/dev/null || true
  zfs unmount -a 2>/dev/null || true
  zpool export -f -a 2>/dev/null || true
  dmsetup remove_all -f 2>/dev/null || true
  vgchange -an 2>/dev/null || true
  mdadm --stop --scan 2>/dev/null || true

  for disk in "${target_disks[@]}"; do
    echo "☢️ Nuking ${disk}..."

    echo "   - Running blkdiscard..."
    blkdiscard -f "${disk}" 2>/dev/null || echo "     Warning: blkdiscard failed or is unsupported. Proceeding to software wipe..."

    echo "   - Wiping filesystem signatures..."
    wipefs -a -f "${disk}p"* 2>/dev/null || true
    wipefs -a -f "${disk}-part"* 2>/dev/null || true
    wipefs -a -f "${disk}" 2>/dev/null || true

    echo "   - Zapping partition table..."
    sgdisk --zap-all "${disk}" >/dev/null 2>&1 || true

    echo "   - Zeroing headers (fallback)..."
    dd if=/dev/zero of="${disk}" bs=1M count=100 status=none || true

    echo "   - Probing kernel cache..."
    partprobe "${disk}" 2>/dev/null || echo "     Warning: partprobe failed. The kernel is locked. A reboot is recommended."
    sleep 2
  done
  echo "✅ Wipe sequence complete. Disks are virgin hardware."
}

deploy_local() {
  if [ "${EUID}" -ne 0 ]; then
    die "Local deployment requires root privileges. Please run with sudo."
  fi

  local disk_file="disk_ids/${TARGET_HOST}.txt"
  if [ ! -f "${disk_file}" ]; then
    die "Disk list file '${disk_file}' not found."
  fi

  local disks=()
  mapfile -t disks < <(grep -v '^[[:space:]]*$' "${disk_file}" || true)

  if [ "${#disks[@]}" -eq 0 ]; then
    die "File ${disk_file} is empty or contains no valid disk IDs."
  fi

  for disk in "${disks[@]}"; do
    if [ ! -b "${disk}" ]; then
      die "Hardware target '${disk}' is not a valid block device on this machine."
    fi
  done

  if [ "${WIPE_DISKS}" = "yes" ]; then
    wipe_target_disks "${disks[@]}"
  fi

  local disko_args=()
  if [ "${#disks[@]}" -eq 1 ]; then
    echo "Detected 1 disk. Configuring for single drive..."
    disko_args+=(--disk main "${disks[0]}")
  elif [ "${#disks[@]}" -eq 2 ]; then
    echo "Detected 2 disks. Configuring for mirror..."
    disko_args+=(--disk main "${disks[0]}" --disk secondary "${disks[1]}")
  else
    die "Script expects 1 or 2 disks. Found ${#disks[@]} in ${disk_file}."
  fi

  if [ -d "/sys/firmware/efi" ]; then
    disko_args+=(--write-efi-boot-entries)
  fi

  echo "⚙️ Deploying configuration for host: ${TARGET_HOST} locally..."

  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko#disko-install" -- \
    --flake ".#${TARGET_HOST}" \
    "${disko_args[@]}"
}

deploy_remote() {
  echo "🚀 Initiating remote deployment for ${TARGET_HOST} at ${REMOTE_IP}..."
  echo "🔑 You will be prompted for the root SSH password exactly once."

  local remote_args="--target '${TARGET_HOST}'"
  if [ "${WIPE_DISKS}" = "yes" ]; then
    remote_args="${remote_args} --wipe-disks"
  fi

  ssh "root@${REMOTE_IP}" "
    set -euo pipefail

    echo '1. Cloning repository on remote target...'
    rm -rf /tmp/config
    git clone --depth 1 '${REPO_URL}' /tmp/config

    echo '2. Executing local install phase on remote target...'
    cd /tmp/config
    chmod +x deploy.sh
    ./deploy.sh ${remote_args}
  "

  if [ "${REBOOT_REMOTE}" = "yes" ]; then
    echo "🔄 Rebooting remote target..."
    ssh "root@${REMOTE_IP}" "reboot" || true
    echo "✅ Remote deployment finished. Target is rebooting."
  else
    echo "✅ Remote deployment finished. Reboot skipped."
  fi
}

# --- Main Entry Point ---

main() {
  parse_args "${@}"

  if [ "${DEPLOY_MODE}" = "remote" ]; then
    deploy_remote
  else
    deploy_local
  fi
}

main "${@}"
