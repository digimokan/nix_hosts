#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
REPO_URL="https://github.com/digimokan/nix_hosts.git"

# --- Globals ---
TARGET_HOST=""
REMOTE_IP=""
DEPLOY_MODE=""
WIPE_DISKS="no"
REBOOT_REMOTE="yes"
PROMPT_KEY="no"
EDIT_SECRET_FILE=""
FORMAT_USER_DATA="no"
FORMAT_SERVER_DATA="no"
DATA_DISK_IDS=()

# ==========================================
# Utility Functions
# ==========================================

die() {
  printf "Error: %s\n" "${1}" >&2
  exit 1
}

print_usage() {
  cat <<EOF
USAGE: $(basename "${0}") [COMMAND] [OPTIONS]

PURPOSE:
  * Format disks via Disko, deploy NixOS, and securely inject pure-Age SOPS keys.
  * Facilitates both local orchestration (on the target machine) and remote
    orchestration (from an external machine via SSH).
  * Manage SOPS secrets files.

COMMANDS:
  --deploy-local             Execute deployment directly on the current machine.
                             (Requires running from the NixOS Live ISO).
  --deploy-remote            Execute deployment on a remote target over SSH.
                             (Requires the -R/--remote option).
  -w, --wipe-disks           Aggressively nuke old partitions and labels.
                             SAFETY: Only executes on disks defined in host's Disko config.
  --format-user-data-disk    Format targeted disk(s) as an encrypted ZFS user data pool.
  --format-server-data-disk  Format targeted disk(s) as an unencrypted ZFS server data pool.
  -e, --edit-secret FILE     Edit a SOPS file and automatically rekey all secrets.
  -h, --help                 Show this help menu and exit

OPTIONS:
  -T, --target HOST      (Required for deploy/format) The NixOS configuration name (e.g., nas)
  -R, --remote IP        (Required for --deploy-remote) Target IP address
  -D, --data-disk ID     (Required for --format-*) Physical disk ID to format (can pass multiple for mirror)
  -p, --prompt-key       (Optional for --deploy-local) Securely prompt for the Age Master Key
  -N, --no-reboot-remote (Optional for --deploy-remote) Do not reboot after deployment

EXAMPLES:
  Local Deploy   (run on minimal ISO): sudo ./$(basename "${0}") --deploy-local -p -w -T nas
  Remote Deploy  (SSH to minimal ISO):      ./$(basename "${0}") --deploy-remote -w -T nas -R 192.168.1.50
  Local Format   (run on minimal ISO): sudo ./$(basename "${0}") --format-user-data-disk -D /dev/disk/by-id/xxxx -T nas
  Remote Format  (run on dev machine):      ./$(basename "${0}") --format-user-data-disk -D /dev/disk/by-id/xxxx -T nas -R 192.168.1.50
  Remote Fmt+Dep (SSH to minimal ISO):      ./$(basename "${0}") --deploy-remote --format-server-data-disk -D /dev/disk/by-id/xxxx -w -T nas -R 192.168.1.50
  Local Wipe     (run on minimal ISO): sudo ./$(basename "${0}") -w -T nas
  Edit Secret    (run on dev machine):      ./$(basename "${0}") -e secrets/master_secrets.yaml
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
      -N|--no-reboot-remote)
        REBOOT_REMOTE="no"
        shift
        ;;
      -p|--prompt-key)
        PROMPT_KEY="yes"
        shift
        ;;
      --deploy-local)
        DEPLOY_MODE="local"
        shift
        ;;
      --deploy-remote)
        DEPLOY_MODE="remote"
        shift
        ;;
      -e|--edit-secret)
        shift
        if [ "${#}" -eq 0 ] || [ "${1:0:1}" = "-" ]; then
          die "Argument for --edit-secret is missing."
        fi
        EDIT_SECRET_FILE="${1}"
        shift
        ;;
      --format-user-data-disk)
        FORMAT_USER_DATA="yes"
        shift
        ;;
      --format-server-data-disk)
        FORMAT_SERVER_DATA="yes"
        shift
        ;;
      -T|--target|-R|--remote)
        shift
        if [ "${#}" -eq 0 ] || [ "${1:0:1}" = "-" ]; then
          die "Argument for ${flag} is missing."
        fi
        local val="${1}"
        case "${flag}" in
          -T|--target) TARGET_HOST="${val}" ;;
          -R|--remote) REMOTE_IP="${val}" ;;
        esac
        shift
        ;;
      -D|--data-disk)
        shift
        if [ "${#}" -eq 0 ] || [ "${1:0:1}" = "-" ]; then
          die "Argument for --data-disk is missing."
        fi
        DATA_DISK_IDS+=("${1}")
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

  # Validation
  if [ -z "${DEPLOY_MODE}" ] && [ "${WIPE_DISKS}" = "no" ] && [ -z "${EDIT_SECRET_FILE}" ] && [ "${FORMAT_USER_DATA}" = "no" ] && [ "${FORMAT_SERVER_DATA}" = "no" ]; then
    errmsg="You must specify a command:"
    errmsg="${errmsg} --deploy-local, --deploy-remote,"
    errmsg="${errmsg} -w/--wipe-disks, -e/--edit-secret,"
    errmsg="${errmsg} --format-user-data-disk, --format-server-data-disk."
    die "${errmsg}"
  fi

  if [ -n "${DEPLOY_MODE}" ] && [ -z "${TARGET_HOST}" ]; then
    die "The -T/--target option is required for deployment."
  fi
  if [ "${DEPLOY_MODE}" = "remote" ] && [ -z "${REMOTE_IP}" ]; then
    die "The -R/--remote option is required when using --deploy-remote."
  fi
  if [ "${FORMAT_USER_DATA}" = "yes" ] || [ "${FORMAT_SERVER_DATA}" = "yes" ]; then
    if [ "${#DATA_DISK_IDS[@]}" -eq 0 ]; then
      die "You must specify at least one target disk via -D/--data-disk when formatting."
    fi
    if [ -z "${TARGET_HOST}" ]; then
      die "You must specify a -T/--target host when formatting a data disk."
    fi
  fi
}

query_nix_config() {
  local target="${1}"
  local query="${2}"
  local apply="${3:-}"

  if [ -n "${apply}" ]; then
    nix --extra-experimental-features "nix-command flakes" \
    eval --raw ".#nixosConfigurations.${target}.config.${query}" \
    --apply "${apply}" 2>/dev/null || true
  else
    nix --extra-experimental-features "nix-command flakes" \
    eval --raw ".#nixosConfigurations.${target}.config.${query}" \
    2>/dev/null || true
  fi
}

run_sops() {
  if ! command -v sops &> /dev/null; then
    nix --extra-experimental-features "nix-command flakes" \
    shell nixpkgs#sops --command sops "$@"
  else
    sops "$@"
  fi
}

get_sops_secret() {
  local secret_key="${1}"
  local file_path="${2}"

  if [ ! -f "${file_path}" ]; then return 1; fi
  run_sops -d --extract "[\"${secret_key}\"]" "${file_path}" 2>/dev/null || true
}

prompt_for_master_key() {
  echo ""
  echo "🔒 LOCAL DEPLOYMENT DETECTED 🔒"
  echo "To decrypt the host key locally, you must provide your Age Master Private Key."
  echo "Your input will be hidden and stored only in volatile memory for this session."

  # Ensure the prompt goes to stderr so it displays properly, while reading from stdin
  read -r -s -p "Enter Age Master Key (or just the part after 'AGE-SECRET-KEY-'): " RAW_INPUT < /dev/tty
  echo "" >&2 # Print a newline after the hidden input

  if [ -z "${RAW_INPUT}" ]; then
    die "No key provided."
  fi

  # Forgive the user if they typed or pasted the prefix, otherwise prepend it for them
  if [[ "${RAW_INPUT}" == AGE-SECRET-KEY-* ]]; then
    LOCAL_MASTER_KEY="${RAW_INPUT}"
  else
    LOCAL_MASTER_KEY="AGE-SECRET-KEY-${RAW_INPUT}"
  fi

  # Basic validation: A valid standard Age secret key is always 74 characters long
  if [ "${#LOCAL_MASTER_KEY}" -ne 74 ]; then
    die "Invalid key length. An Age secret key must be exactly 74 characters long (currently ${#LOCAL_MASTER_KEY})."
  fi

  # Export it so SOPS can pick it up automatically
  export SOPS_AGE_KEY="${LOCAL_MASTER_KEY}"
}

extract_host_key() {
  echo "🔐 Attempting to extract pure-Age keypair for host '${TARGET_HOST}'..." >&2

  local secrets_file="secrets/master_secrets.yaml"
  if [ ! -f "${secrets_file}" ]; then
    die "Admin secrets vault not found at: ${secrets_file}"
  fi

  local key_value
  # SOPS will automatically use the SOPS_AGE_KEY environment variable if it's set
  if ! key_value=$(get_sops_secret "age_keypair_host_${TARGET_HOST}" "${secrets_file}"); then
    die "Could not find 'age_keypair_host_${TARGET_HOST}' inside ${secrets_file}."
  fi

  # CRITICAL SECURITY STEP: Purge the master key from memory immediately after use
  if [ -n "${LOCAL_MASTER_KEY:-}" ]; then
    unset SOPS_AGE_KEY
    unset LOCAL_MASTER_KEY
    echo "🧹 Master key purged from active memory." >&2
  fi

  local temp_key_file
  temp_key_file=$(mktemp)
  chmod 600 "${temp_key_file}"
  echo "${key_value}" > "${temp_key_file}"

  echo "✅ Host keypair extracted successfully." >&2
  echo "${temp_key_file}"
}

extract_zfs_passphrase() {
  local target="${1}"
  local secrets_file="secrets/${target}_host_secrets.yaml"

  if [ ! -f "${secrets_file}" ]; then return 0; fi

  # Check if host type requires encryption via Nix
  local host_type
  host_type=$(query_nix_config "${target}" "custom.infrastructure.hostType")

  if [ "${host_type}" != "user-facing" ]; then
    return 0
  fi

  echo "🔑 Extracting plaintext ZFS passphrase for deployment..." >&2
  local pass_value
  if ! pass_value=$(get_sops_secret "${target}_host_zfs_encryption_passphrase" "${secrets_file}"); then
    die "Failed to extract '${target}_host_zfs_encryption_passphrase' for user-facing host."
  fi

  echo -n "${pass_value}" > /tmp/zfs_passphrase
}

inject_sops_host_keypair_to_mnt() {
  local key_path="${1}"
  echo "💉 Injecting SOPS host keypair into the newly formatted volume (/mnt)..."
  mkdir -p /mnt/var/lib/sops-nix
  cp "${key_path}" /mnt/var/lib/sops-nix/host_keypair.age
  chmod 400 /mnt/var/lib/sops-nix/host_keypair.age
  echo "✅ SOPS keypair injected successfully."
}

emplace_target_hostid() {
  local target="${1}"
  echo "🧬 Extracting target hostId to prevent ZFS import mismatch..."
  local target_hostid
  target_hostid=$(query_nix_config "${target}" "networking.hostId")

  if [ -z "${target_hostid}" ]; then
    die "Could not extract networking.hostId for '${target}'."
  fi

  # The Live ISO symlinks /etc/hostid to the read-only Nix store.
  # Remove the symlink and write the target's hostId to the RAM overlay filesystem.
  rm -f /etc/hostid
  zgenhostid "${target_hostid}"
  echo "✅ Installer hostId temporarily assumed as ${target_hostid}."
}

deep_wipe_partition() {
  local part="${1}"
  echo "   - Erasing signatures on ${part}..."
  mdadm --zero-superblock --force "${part}" 2>/dev/null || true
  zpool labelclear -f "${part}" 2>/dev/null || true
  wipefs -a -f "${part}" 2>/dev/null || true
}

deep_wipe_disk() {
  local disk="${1}"
  echo "☢️  Nuking ${disk}..."

  local partitions
  partitions=$(lsblk -plno NAME "${disk}" 2>/dev/null | sort -r)
  for part in ${partitions}; do
    if [ "${part}" != "${disk}" ]; then
      deep_wipe_partition "${part}"
    fi
  done

  blkdiscard -f "${disk}" 2>/dev/null || true
  mdadm --zero-superblock --force "${disk}" 2>/dev/null || true
  zpool labelclear -f "${disk}" 2>/dev/null || true
  wipefs -a -f "${disk}" 2>/dev/null || true
  sgdisk --zap-all "${disk}" >/dev/null 2>&1 || true
  partprobe "${disk}" 2>/dev/null || echo "   Warning: partprobe failed."
  sleep 2
}

wipe_target_disks() {
  local target="${1}"

  echo "🛡️ Validating safety constraints for disk wipe..."

  if [ "$(uname -s)" != "Linux" ]; then
    die "Safety abort: Disks can only be wiped on a Linux system."
  fi

  if ! command -v nixos-install &> /dev/null; then
    die "Safety abort: 'nixos-install' not found. You do not appear to be running the NixOS Live ISO."
  fi

  echo "🔍 Querying flake configuration for target disks..."
  local raw_disk_output
  local nix_apply='x: builtins.concatStringsSep "\n" (builtins.map (d: d.device) (builtins.attrValues x))'
  raw_disk_output=$(query_nix_config "${target}" "disko.devices.disk" "${nix_apply}")

  local target_disks=()
  while IFS= read -r disk; do
    if [[ -n "${disk}" && "${disk}" == /dev/* ]]; then
      target_disks+=("${disk}")
    fi
  done <<< "${raw_disk_output}"

  if [ "${#target_disks[@]}" -eq 0 ]; then
    die "No target disks found in Disko configuration for host '${target}'. Cannot proceed with safe wipe."
  fi

  echo ""
  echo "⚠️  WARNING: You are about to DESTROY ALL DATA on the following EXPLICITLY TARGETED disks:"
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
    echo "SSH Session detected. Proceeding with targeted wipe automatically based on -w flag."
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
    deep_wipe_disk "${disk}"
    sleep 2
  done
  echo "✅ Targeted wipe sequence complete."
}

execute_zpool_create() {
  local target="${1}"
  local format_type="${2}" # "user" or "server"
  local pool_name="zdata_${target}"
  local pool_mode=""

  if [ "${#DATA_DISK_IDS[@]}" -eq 2 ]; then pool_mode="mirror"; fi

  # Query Nix for Compatibility
  local compat_val
  compat_val=$(query_nix_config "${target}" "disko.devices.zpool.zroot.options.compatibility")
  local compat_flag=""
  if [ -n "${compat_val}" ]; then compat_flag="-o compatibility=${compat_val}"; fi

  # Extract Secrets (if user data disk)
  local enc_flags=""
  local temp_key="/tmp/${pool_name}.key"

  if [ "${format_type}" = "user" ]; then
    local hex_key
    hex_key=$(get_sops_secret "${target}_host_zfs_zdata_encryption_symkey" "secrets/${target}_host_secrets.yaml")
    if [ -z "${hex_key}" ]; then die "Failed to extract data disk encryption key."; fi
    echo -n "${hex_key}" > "${temp_key}"
    enc_flags="-O encryption=aes-256-gcm -O keyformat=hex -O keylocation=file://${temp_key}"
  fi

  # shellcheck disable=SC2086
  zpool create -o ashift=12 ${compat_flag} \
    -O compression=lz4 \
    -O xattr=sa \
    -O acltype=posixacl \
    -O atime=off \
    ${enc_flags} \
    -m none \
    "${pool_name}" ${pool_mode} "${DATA_DISK_IDS[@]}"

  # Create base dataset with legacy mountpoint to defer mounting to systemd
  local base_dataset="data"
  if [ "${format_type}" = "user" ]; then base_dataset="home"; fi
  zfs create -o mountpoint=legacy "${pool_name}/${base_dataset}"

  zpool export "${pool_name}"
  rm -f "${temp_key}"
  echo "✅ ${format_type} data drive formatted successfully."
}

format_data_disk() {
  local target="${1}"
  local format_type="${2}"

  if [ "${EUID}" -ne 0 ]; then
    die "Formatting disks requires root privileges."
  fi

  local host_type
  host_type=$(query_nix_config "${target}" "custom.infrastructure.hostType")

  if [ "${format_type}" = "user" ] && [ "${host_type}" != "user-facing" ]; then
    die "Safety abort: You requested user-data format, but host ${target} is type '${host_type}'."
  fi
  if [ "${format_type}" = "server" ] && [ "${host_type}" != "server" ]; then
    die "Safety abort: You requested server-data format, but host ${target} is type '${host_type}'."
  fi

  echo ""
  echo "⚠️  WARNING: You are about to DESTROY ALL DATA on these explicitly targeted disks:"
  for disk in "${DATA_DISK_IDS[@]}"; do
    echo "   -> ${disk}"
  done
  echo ""

  if [ -t 0 ]; then
    read -r -p "Type 'NUKE' in all caps to confirm destruction: " confirm_wipe
    if [ "${confirm_wipe}" != "NUKE" ]; then
      die "Data format aborted by user."
    fi
  else
    echo "SSH Session detected. Proceeding automatically based on command flags."
  fi

  for disk in "${DATA_DISK_IDS[@]}"; do
    deep_wipe_disk "${disk}"
  done

  execute_zpool_create "${target}" "${format_type}"
}

execute_disko_format() {
  local target="${1}"
  echo "⚙️  Formatting disks via Disko..."

  extract_zfs_passphrase "${target}"

  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko" -- --mode format --flake ".#${target}"

  rm -f /tmp/zfs_passphrase

  echo "⏳ Waiting for USB enclosure block devices to settle..."
  udevadm settle
  echo "✅ Disko formatting complete."

  echo "⚙️  Mounting disks to /mnt via Disko..."
  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko" -- --mode mount --flake ".#${target}"
  echo "✅ Disko mounting complete."
}

execute_nixos_install() {
  local target="${1}"
  echo "🚀 Installing NixOS to /mnt..."
  # Note: do not have installer prompt to set initial root password
  nixos-install --flake ".#${target}" --no-root-passwd
  echo "✅ NixOS installation complete."
}

# This function contains the actual build steps, meant to run on the target host
run_build_sequence() {
  local target="${1}"
  local do_wipe="${2}"
  local key_file="${3}"

  if [ "${EUID}" -ne 0 ]; then
    die "Build sequence requires root privileges."
  fi

  emplace_target_hostid "${target}"

  if [ "${do_wipe}" = "yes" ]; then
    wipe_target_disks "${target}"
  fi

  execute_disko_format "${target}"
  inject_sops_host_keypair_to_mnt "${key_file}"
  execute_nixos_install "${target}"
}

deploy_local() {
  echo "🚀 Initiating local deployment for ${TARGET_HOST}..."

  if [ "${PROMPT_KEY}" = "yes" ]; then
    prompt_for_master_key
  fi

  local temp_key_file
  temp_key_file=$(extract_host_key)

  run_build_sequence "${TARGET_HOST}" "${WIPE_DISKS}" "${temp_key_file}"

  rm -f "${temp_key_file}"
  echo "✅ Local deployment finished."
}

deploy_remote() {
  echo "🚀 Initiating remote orchestration for ${TARGET_HOST} at ${REMOTE_IP}..."

  local temp_key_file
  temp_key_file=$(extract_host_key)

  # SSH Multiplexing options: Authenticate once and reuse the connection
  local ssh_opts=(-o ControlMaster=auto -o ControlPath=/tmp/deploy_ssh_%h_%p_%r -o ControlPersist=10m)

  echo "📦 Cloning repository on remote target..."
  # shellcheck disable=SC2029
  ssh "${ssh_opts[@]}" "nixos@${REMOTE_IP}" "rm -rf /tmp/nix_hosts && git clone --single-branch --depth=1 '${REPO_URL}' /tmp/nix_hosts"
  echo "✅ Repository cloned successfully."

  echo "💉 Transferring SOPS keypair to remote temporary storage..."
  ssh "${ssh_opts[@]}" "nixos@${REMOTE_IP}" "mkdir -p /tmp/secrets"
  scp "${ssh_opts[@]}" "${temp_key_file}" "nixos@${REMOTE_IP}:/tmp/secrets/host_keypair.age"
  echo "✅ Keypair transferred successfully."

  # Clean up local key
  rm -f "${temp_key_file}"

  echo "⚙️ Executing build sequence over SSH..."

  # Elevate to root via sudo for the build sequence
  ssh "${ssh_opts[@]}" "nixos@${REMOTE_IP}" 'sudo bash -s' -- "${TARGET_HOST}" "${WIPE_DISKS}" << 'EOF'
    set -euo pipefail
    cd /tmp/nix_hosts

    local_target="${1}"
    local_wipe="${2}"

    source ./run.sh ""
    run_build_sequence "${local_target}" "${local_wipe}" "/tmp/secrets/host_keypair.age"
    rm -rf /tmp/secrets
EOF

  if [ "${REBOOT_REMOTE}" = "yes" ]; then
    echo "🔄 Rebooting remote target..."
    ssh "${ssh_opts[@]}" "nixos@${REMOTE_IP}" "sudo reboot" || true
    echo "✅ Remote deployment finished. Target is rebooting."
  else
    echo "✅ Remote deployment finished. Reboot into the newly-installed host."
  fi
}

edit_and_rekey() {
  local target_file="${1}"

  if [ ! -f "${target_file}" ]; then
    die "Target file not found: ${target_file}"
  fi

  echo "📝 Opening ${target_file} via SOPS..."
  run_sops "${target_file}"

  echo "🔄 Rekeying all YAML files in secrets/ directory..."
  for secret_file in secrets/*.yaml; do
    if [ -f "${secret_file}" ]; then
      echo "   - Updating keys for ${secret_file}..."
      run_sops updatekeys -y "${secret_file}" || echo "Warning: Failed to rekey ${secret_file}"
    fi
  done
  echo "✅ Secrets modification and rekey operations complete. Commit changes to Git."
}

# ==========================================
# Main Entry Point
# ==========================================

# Only execute main if the script is run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_args "${@}"

  if [ -n "${EDIT_SECRET_FILE}" ]; then
    edit_and_rekey "${EDIT_SECRET_FILE}"
    exit 0
  fi

  if [ "${FORMAT_USER_DATA}" = "yes" ]; then
    format_data_disk "${TARGET_HOST}" "user"
  elif [ "${FORMAT_SERVER_DATA}" = "yes" ]; then
    format_data_disk "${TARGET_HOST}" "server"
  fi

  if [ "${DEPLOY_MODE}" = "remote" ]; then
    deploy_remote
  elif [ "${DEPLOY_MODE}" = "local" ]; then
    deploy_local
  elif [ "${WIPE_DISKS}" = "yes" ] && [ -z "${DEPLOY_MODE}" ]; then
    if [ "${EUID}" -ne 0 ]; then
      die "Wiping disks requires root privileges. Please run with sudo."
    fi
    wipe_target_disks "${TARGET_HOST}"
  fi
fi

