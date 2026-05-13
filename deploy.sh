#!/usr/bin/env bash

set -euo pipefail

# --- Globals ---
TARGET_HOST=""
REMOTE_IP=""
DEPLOY_MODE="local"
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
  * Format disks, deploy NixOS, and securely inject pure-Age SOPS cryptography.
  * For remote deployments, the orchestrating machine decrypts the host keypair
  locally and securely transfers it to the target over SSH.

  OPTIONS:
  -t, --target HOST      (Required) The NixOS configuration name (e.g., nas)
  -r, --remote IP        (Optional) Deploy remotely to the target IP address
  -w, --wipe-disks       (Optional) Aggressively nuke old partitions and labels
  SAFETY: Only executes if running on the NixOS Live ISO.
  -n, --no-reboot-remote (Optional) Do NOT reboot the remote machine after deployment
  -h, --help             Show this help menu and exit

  CRYPTOGRAPHY:
  The script automatically searches for the target's Age keypair inside:
  secrets/admin_secrets.yaml (Look for key: age_keypair_host_<HOST>)
  It utilizes the SOPS_AGE_KEY environment variable (or ~/.config/sops/age/keys.txt)
  for decryption on the orchestrating machine.

    EXAMPLES:
    Local Deploy (from minimal ISO):  sudo ./$(basename "${0}") -t nas -w
    Remote Deploy (SSH to minimal ISO): ./$(basename "${0}") -t nas -r 192.168.1.50 -w
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
      -n|--no-reboot-remote)
        REBOOT_REMOTE="no"
        shift
        ;;
      -t|--target|-r|--remote)
        shift
        if [ "${#}" -eq 0 ] || [ "${1:0:1}" = "-" ]; then
          die "Argument for ${flag} is missing."
        fi

        local val="${1}"
        case "${flag}" in
          -t|--target) TARGET_HOST="${val}" ;;
          -r|--remote) REMOTE_IP="${val}"; DEPLOY_MODE="remote" ;;
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

# --- Cryptography Extraction ---

extract_host_key() {
  echo "🔐 Attempting to extract pure-Age keypair for host '${TARGET_HOST}'..."

  local secrets_file="secrets/admin_secrets.yaml"
  if [ ! -f "${secrets_file}" ]; then
    die "Admin secrets vault not found at: ${secrets_file}"
  fi

  # Use SOPS to decrypt the vault, and yq (nix-shell) to parse the specific key
  local key_value
  key_value=$(nix-shell -p yq --run "sops -d ${secrets_file} | yq -r '.age_keypair_host_${TARGET_HOST} // empty'")

  if [ -z "${key_value}" ]; then
    die "Could not find 'age_keypair_host_${TARGET_HOST}' inside ${secrets_file}. Did you add it?"
  fi

  # Write the extracted key to a highly secure temporary file
  local temp_key_file
  temp_key_file=$(mktemp)
  chmod 600 "${temp_key_file}"
  echo "${key_value}" > "${temp_key_file}"

  echo "✅ Host keypair extracted successfully."
  echo "${temp_key_file}"
}

# --- Disk Wiping ---

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

# --- Deployment Logic ---

deploy_local() {
  if [ "${EUID}" -ne 0 ]; then
    die "Local deployment requires root privileges. Please run with sudo."
  fi

  # 1. Read Disk Configuration
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

  # 2. Wipe Disks (If Requested)
  if [ "${WIPE_DISKS}" = "yes" ]; then
    wipe_target_disks "${disks[@]}"
  fi

  # 3. Prepare Disko Arguments
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

  # 4. Extract Keypair (Locally)
  local temp_key_file
  temp_key_file=$(extract_host_key)

  # 5. Format Disks (Mounts them to /mnt)
  echo "⚙️ Formatting disks via Disko..."
  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko#disko-install" -- \
      --flake ".#${TARGET_HOST}" \
      --mode disko \
      "${disko_args[@]}"

    # 6. Inject the Keypair
    echo "💉 Injecting SOPS host keypair into the newly formatted volume..."
    mkdir -p /mnt/var/lib/sops-nix
    cp "${temp_key_file}" /mnt/var/lib/sops-nix/host_keypair.age
    chmod 400 /mnt/var/lib/sops-nix/host_keypair.age
    rm -f "${temp_key_file}"

    # 7. Install NixOS
    echo "🚀 Installing NixOS to /mnt..."
    nixos-install --flake ".#${TARGET_HOST}" --no-root-passwd

    echo "✅ Local deployment finished."
  }

deploy_remote() {
  echo "🚀 Initiating remote orchestration for ${TARGET_HOST} at ${REMOTE_IP}..."

  # 1. Extract Keypair (On the Orchestrating Machine)
  local temp_key_file
  temp_key_file=$(extract_host_key)

  # 2. Sync Repository to Target
  echo "📦 Syncing repository to remote /tmp/nix_hosts..."
  ssh "root@${REMOTE_IP}" "mkdir -p /tmp/nix_hosts"
  rsync -avz --delete ./ "root@${REMOTE_IP}:/tmp/nix_hosts/"

  # 3. Construct Remote Command Arguments
  local remote_args="--target '${TARGET_HOST}'"
  if [ "${WIPE_DISKS}" = "yes" ]; then
    remote_args="${remote_args} --wipe-disks"
  fi

  # 4. Execute Formatting & Installation via SSH
  echo "⚙️ Executing build script on remote target..."
  ssh "root@${REMOTE_IP}" "
  set -euo pipefail
  cd /tmp/nix_hosts

  # We skip extraction on the remote side, so we mimic the local deployment steps

  # 1. Read Disks
  mapfile -t disks < <(grep -v '^[[:space:]]*$' 'disk_ids/${TARGET_HOST}.txt' || true)

  # 2. Wipe
  if [ '${WIPE_DISKS}' = 'yes' ]; then
    ./deploy.sh ${remote_args} # Let the script call itself to handle the wipe logic
  fi

  # 3. Disko Args
  disko_args=()
  if [ \${#disks[@]} -eq 1 ]; then
    disko_args+=(--disk main \"\${disks[0]}\")
  elif [ \${#disks[@]} -eq 2 ]; then
    disko_args+=(--disk main \"\${disks[0]}\" --disk secondary \"\${disks[1]}\")
  fi
  if [ -d '/sys/firmware/efi' ]; then
    disko_args+=(--write-efi-boot-entries)
  fi

  # 4. Format
  echo '⚙️ Formatting remote disks via Disko...'
  nix --extra-experimental-features 'nix-command flakes' \
    run 'github:nix-community/disko#disko-install' -- \
    --flake '.#${TARGET_HOST}' \
    --mode disko \
    \"\${disko_args[@]}\"
  "

  # 5. Inject the Keypair over SSH
  echo "💉 Securely injecting SOPS host keypair to remote /mnt..."
  ssh "root@${REMOTE_IP}" "mkdir -p /mnt/var/lib/sops-nix"
  scp "${temp_key_file}" "root@${REMOTE_IP}:/mnt/var/lib/sops-nix/host_keypair.age"
  ssh "root@${REMOTE_IP}" "chmod 400 /mnt/var/lib/sops-nix/host_keypair.age"
  rm -f "${temp_key_file}" # Clean up local copy

  # 6. Finalize Installation over SSH
  echo "🚀 Finalizing NixOS installation on remote..."
  ssh "root@${REMOTE_IP}" "
  nixos-install --flake '/tmp/nix_hosts#${TARGET_HOST}' --no-root-passwd
  "

  # 7. Reboot
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
