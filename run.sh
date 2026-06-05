#!/usr/bin/env bash
# shellcheck shell=bash

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
  --format-user-data-disk    format user-facing-host disk(s) with empty zdata pool
  --format-server-data-disk  format server-host disk(s) with empty zdata pool
  -e, --edit-secret FILE     Edit a SOPS file and automatically rekey all secrets.
  -h, --help                 Show this help menu and exit

OPTIONS:
  -T, --target HOST      (Required for deploy) The NixOS configuration name (e.g., nas)
  -D, --data-disk PATH   (Required for --format-data-disk, multiple for mirrored drives)
  -R, --remote IP        (Required for --deploy-remote) Target IP address
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
if [ -z "${DEPLOY_MODE}" ] && \
   [ "${WIPE_DISKS}" = "no" ] && \
   [ -z "${EDIT_SECRET_FILE}" ] && \
   [ "${FORMAT_USER_DATA}" = "no" ] && \
   [ "${FORMAT_SERVER_DATA}" = "no" ]; then
    errmsg="You must specify a command:"
    errmsg="${errmsg} --deploy-local,"
    errmsg="${errmsg} --deploy-remote,"
    errmsg="${errmsg} -w/--wipe-disks,"
    errmsg="${errmsg} -e/--edit-secret,"
    errmsg="${errmsg} --format-user-data-disk,"
    errmsg="${errmsg} --format-server-data-disk."
    die "${errmsg}"
  fi

  if [ "${FORMAT_USER_DATA}" = "yes" ] && [ -z "${DATA_DISK_ID}" ]; then
    die "You must specify a target disk via -D/--data-disk when using --format-data-disk."
  fi

  if [ "${FORMAT_SERVER_DATA}" = "yes" ] && [ -z "${TARGET_HOST}" ]; then
    die "You must specify a -T/--target host when formatting a data disk."
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

deep_wipe_partition() {
  local part="${1}"
  echo "    - Erasing signatures on ${part}..."
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
  partprobe "${disk}" 2>/dev/null || echo "    Warning: partprobe failed. The kernel is locked. A reboot is recommended."
  sleep 2
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

  # Determine the sops command based on environment (Native vs Live ISO)
  local sops_cmd="sops"
  if ! command -v sops &> /dev/null; then
    echo "   - Native 'sops' not found. Fetching temporarily via Nix..." >&2
    sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
  fi

  local key_value
  # SOPS will automatically use the SOPS_AGE_KEY environment variable if it's set
  key_value=$(eval "${sops_cmd} -d '${secrets_file}'" | awk -v target="age_keypair_host_${TARGET_HOST}:" '
    $0 ~ target {flag=1; next}
    flag && /^[[:space:]]/ {print; next}
    flag && /^[^[:space:]]/ {flag=0}
  ')

  # CRITICAL SECURITY STEP: Purge the master key from memory immediately after use
  if [ -n "${LOCAL_MASTER_KEY:-}" ]; then
    unset SOPS_AGE_KEY
    unset LOCAL_MASTER_KEY
    echo "🧹 Master key purged from active memory." >&2
  fi

  if [ -z "${key_value}" ]; then
    die "Could not find 'age_keypair_host_${TARGET_HOST}' inside ${secrets_file}."
  fi

  # Strip leading whitespace block indicator that YAML requires
  # shellcheck disable=SC2001
  key_value=$(echo "${key_value}" | sed 's/^[[:space:]]*//')

  local temp_key_file
  temp_key_file=$(mktemp)
  chmod 600 "${temp_key_file}"
  echo "${key_value}" > "${temp_key_file}"

  echo "✅ Host keypair extracted successfully." >&2
  echo "${temp_key_file}"
}

extract_zfs_passphrase() {
  local target="${1}"
  local key_file="${2}"

  echo "🔍 Checking if target '${target}' requires ZFS native encryption..." >&2

  # query Nix config to see if the zroot pool has an encryption option set
  local nix_query=".#nixosConfigurations.${target}.config.disko.devices.zpool.zroot.rootFsOptions.encryption"
  local enc_status
  enc_status=$(nix --extra-experimental-features "nix-command flakes" eval --raw "${nix_query}" 2>/dev/null || true)

  if [ -z "${enc_status}" ]; then
    echo "   - No encryption configured for zroot. Skipping passphrase extraction." >&2
    return 0
  fi

  echo "   - Encryption (${enc_status}) detected. Extracting passphrase..." >&2

  local secrets_file="secrets/${target}_host_secrets.yaml"
  if [ ! -f "${secrets_file}" ]; then
    die "ZFS encryption is required by Disko, but secrets file ${secrets_file} is missing."
  fi

  local sops_cmd="sops"
  if ! command -v sops &> /dev/null; then
    sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
  fi

  # Temporarily instruct SOPS to use the specific host keypair to decrypt the file
  export SOPS_AGE_KEY_FILE="${key_file}"

  local passphrase
  # Execute the extraction, catching failures explicitly
  if ! passphrase=$(eval "${sops_cmd} -d --extract '[\"${target}_host_zfs_zroot_encryption_passphrase\"]' '${secrets_file}'" 2>/dev/null); then
    unset SOPS_AGE_KEY_FILE
    die "Failed to extract '${target}_host_zfs_zroot_encryption_passphrase' from ${secrets_file}. Ensure it exists."
  fi

  unset SOPS_AGE_KEY_FILE

  # -n is critical here to prevent a trailing newline from becoming part of the password
  echo -n "${passphrase}" > "/tmp/zfs_passphrase"
  chmod 600 "/tmp/zfs_passphrase"
  echo "✅ Extracted ZFS plaintext passphrase to secure temporary storage." >&2
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
  target_hostid="$(nix \
    --extra-experimental-features "nix-command flakes" \
    eval \
    --raw \
    ".#nixosConfigurations.${target}.config.networking.hostId"
  )"

  if [ -z "${target_hostid}" ]; then
    die "Could not extract networking.hostId for '${target}'."
  fi

  # The Live ISO symlinks /etc/hostid to the read-only Nix store.
  # Remove the symlink and write the target's hostId to the RAM overlay filesystem.
  rm -f /etc/hostid
  zgenhostid "${target_hostid}"
  echo "✅ Installer hostId temporarily assumed as ${target_hostid}."
}

format_data_disk() {
  local target="${1}"
  local disk_id="${2}"
  local secrets_file="secrets/${target}_secrets.yaml"

  if [ "${EUID}" -ne 0 ]; then
    die "Formatting disks requires root privileges. Please run with sudo."
  fi

  if [ ! -f "${secrets_file}" ]; then
    die "Secrets vault not found at: ${secrets_file}. Cannot retrieve hex key."
  fi

  echo ""
  echo "⚠️  WARNING: You are about to DESTROY ALL DATA on the following EXPLICITLY TARGETED disk:"
  echo "   -> ${disk_id}"
  echo ""

  read -r -p "Type 'NUKE' in all caps to confirm destruction: " confirm_wipe
  if [ "${confirm_wipe}" != "NUKE" ]; then
    die "Data format aborted by user."
  fi

  echo "🔑 Extracting hex key for zdata_${target} from SOPS..."
  local sops_cmd="sops"
  if ! command -v sops &> /dev/null; then
    sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
  fi

  local hex_key
  if ! hex_key=$(eval "${sops_cmd} -d --extract '[\"${target}_host_zfs_zdata_encryption_symkey\"]' '${secrets_file}'" 2>/dev/null); then
    die "Failed to extract '${target}_host_zfs_zdata_encryption_symkey' from ${secrets_file}."
  fi

  local temp_key="/tmp/zdata_${target}.key"
  echo -n "${hex_key}" > "${temp_key}"

  echo "☢️  Nuking ${disk_id} and formatting as zdata_${target}..."
  sgdisk --zap-all "${disk_id}" >/dev/null 2>&1 || true

  zpool create -o ashift=12 \
    -O encryption=aes-256-gcm \
    -O keyformat=hex \
    -O keylocation=file://"${temp_key}" \
    "zdata_${target}" "${disk_id}"

    zfs create -o compression=lz4 "zdata_${target}/home"

    zpool export "zdata_${target}"
    rm -f "${temp_key}"

    echo "✅ Data drive formatted and encrypted successfully."
  }

inject_zdata_key_to_mnt() {
  local target="${1}"
  local secrets_file="secrets/${target}_secrets.yaml"

  if [ ! -f "${secrets_file}" ]; then return 0; fi

  echo "🔑 Checking for persistent zdata key in SOPS..."
  local sops_cmd="sops"
  if ! command -v sops &> /dev/null; then
    sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
  fi

  local hex_key
  hex_key=$(eval "${sops_cmd} -d --extract '[\"host_${target}_zdata_hex_key\"]' '${secrets_file}'" 2>/dev/null || true)

  if [ -n "${hex_key}" ]; then
    echo "   - Key found. Injecting into /mnt/persist/zfs-keys..."
    mkdir -p /mnt/persist/zfs-keys
    echo -n "${hex_key}" > "/mnt/persist/zfs-keys/zdata_${target}.key"
    chmod 400 "/mnt/persist/zfs-keys/zdata_${target}.key"
    echo "✅ Zdata hex key injected successfully."
  fi
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

  local nix_query=".#nixosConfigurations.${target}.config.disko.devices.disk"
  local nix_apply='x: builtins.concatStringsSep "\n" (builtins.map (d: d.device) (builtins.attrValues x))'

  local raw_disk_output
  raw_disk_output="$(query_nix_config "${target}" "disko.devices.disk" "${nix_apply}")"

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
    deep_wipe_disk "${disk}"
    sleep 2
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
    echo "☢️ Nuking ${disk}..."

    # Deep wipe: identify all partitions and the parent disk, reverse sorted
    # so child partitions (e.g., sda2, sda1) are wiped before the parent (sda).
    local partitions
    partitions=$(lsblk -plno NAME "${disk}" 2>/dev/null | sort -r)

    for part in ${partitions}; do
      echo "   - Erasing signatures on ${part}..."
      # Target specific resilient superblocks first
      mdadm --zero-superblock --force "${part}" 2>/dev/null || true
      zpool labelclear -f "${part}" 2>/dev/null || true
      # General wipe for filesystems and partition tables
      wipefs -a -f "${part}" 2>/dev/null || true
    done

    blkdiscard -f "${disk}" 2>/dev/null || true
    mdadm --zero-superblock --force "${disk}" 2>/dev/null || true
    zpool labelclear -f "${disk}" 2>/dev/null || true
    wipefs -a -f "${disk}" 2>/dev/null || true
    sgdisk --zap-all "${disk}" >/dev/null 2>&1 || true

    partprobe "${disk}" 2>/dev/null || echo "     Warning: partprobe failed. The kernel is locked. A reboot is recommended."
    sleep 2
  done

  echo "✅ Targeted wipe sequence complete."
}

execute_data_format() {
  local target="${1}"
  local format_type="${2}" # "user" or "server"

  if [ "${EUID}" -ne 0 ]; then
    die "Formatting disks requires root privileges."
  fi

  local host_type
  host_type="$(nix \
    --extra-experimental-features "nix-command flakes" \
    eval \
    --raw \
    ".#nixosConfigurations.${target}.config.custom.infrastructure.hostType" \
    2>/dev/null || true)"

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

  local compat_flag=""
  local compat_val
  compat_val="$(nix \
    --extra-experimental-features "nix-command flakes" \
    eval \
    --raw \
    ".#nixosConfigurations.${target}.config.disko.devices.zpool.zroot.options.compatibility" \
    2>/dev/null || true)"

  if [ -n "${compat_val}" ]; then
    compat_flag="-o compatibility=${compat_val}"
  fi

  local pool_mode=""
  if [ "${#DATA_DISK_IDS[@]}" -eq 2 ]; then
    pool_mode="mirror"
  elif [ "${#DATA_DISK_IDS[@]}" -gt 2 ]; then
    die "Script currently only supports 1 disk, or 2 disks (mirror)."
  fi

  local pool_name="zdata_${target}"

  for disk in "${DATA_DISK_IDS[@]}"; do
    deep_wipe_disk "${disk}"
  done

  if [ "${format_type}" = "user" ]; then
    local secrets_file="secrets/${target}_secrets.yaml"
    if [ ! -f "${secrets_file}" ]; then
      die "Secrets vault missing: ${secrets_file}. Cannot retrieve hex key."
    fi

    echo "🔑 Extracting hex key for ${pool_name} from SOPS..."
    local sops_cmd="sops"
    if ! command -v sops &> /dev/null; then
      sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
    fi

    local hex_key
    if ! hex_key=$(eval "${sops_cmd} -d --extract '[\"${target}_host_zfs_zdata_encryption_symkey\"]' '${secrets_file}'" 2>/dev/null); then
      die "Failed to extract '${target}_host_zfs_zdata_encryption_symkey'."
    fi

    local temp_key="/tmp/${pool_name}.key"
    echo -n "${hex_key}" > "${temp_key}"

    zpool create -o ashift=12 "${compat_flag}" \
      -O encryption=aes-256-gcm \
      -O keyformat=hex \
      -O keylocation="file://${temp_key}" \
      "${pool_name}" "${pool_mode}" "${DATA_DISK_IDS[@]}"

    # mountpoint=legacy is explicitly required by NixOS fileSystems ZFS mounts
    zfs create -o mountpoint=legacy -o compression=lz4 "${pool_name}/home"

    zpool export "${pool_name}"
    rm -f "${temp_key}"
    echo "✅ User data drive formatted and encrypted successfully."

  elif [ "${format_type}" = "server" ]; then
    zpool create -o ashift=12 "${compat_flag}" \
      -O compression=lz4 \
      -O atime=off \
      -O xattr=sa \
      -O acltype=posixacl \
      -m /data \
      "${pool_name}" ${pool_mode} "${DATA_DISK_IDS[@]}"

    zpool export "${pool_name}"
    echo "✅ Server data drive formatted successfully."
  fi
}

execute_disko_format() {
  local target="${1}"

  echo "⚙️ Formatting disks via Disko..."
  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko" -- --mode format --flake ".#${target}"

  echo "⏳ Waiting for USB enclosure block devices to settle..."
  udevadm settle

  echo "✅ Disko formatting complete."

  echo "⚙️ Mounting disks to /mnt via Disko..."
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

  # Extract the plaintext passphrase directly into the RAM disk before Disko runs
  extract_zfs_passphrase "${target}" "${key_file}"

  execute_disko_format "${target}"

  # Immediately destroy the plaintext passphrase file now that ZFS is formatted
  rm -f "/tmp/zfs_passphrase"

  inject_sops_host_keypair_to_mnt "${key_file}"

  inject_zdata_key_to_mnt "${target}"

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

  local sops_cmd="sops"
  if ! command -v sops &> /dev/null; then
    sops_cmd="nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#sops --command sops"
  fi

  echo "📝 Opening ${target_file} via SOPS..."
  eval "${sops_cmd} '${target_file}'"

  echo "🔄 Rekeying all YAML files in secrets/ directory..."
  for secret_file in secrets/*.yaml; do
    if [ -f "${secret_file}" ]; then
      echo "   - Updating keys for ${secret_file}..."
      eval "${sops_cmd} updatekeys -y '${secret_file}'" || echo "Warning: Failed to rekey ${secret_file}"
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
    execute_data_format "${TARGET_HOST}" "user"
  elif [ "${FORMAT_SERVER_DATA}" = "yes" ]; then
    execute_data_format "${TARGET_HOST}" "server"
  fi

  if [ "${DEPLOY_MODE}" = "remote" ]; then
    deploy_remote
  elif [ "${DEPLOY_MODE}" = "local" ]; then
    deploy_local
  elif [ "${WIPE_DISKS}" = "yes" ] && [ "${DEPLOY_MODE}" = "" ]; then
    if [ "${EUID}" -ne 0 ]; then
      die "Wiping disks requires root privileges."
    fi
    wipe_target_disks "${TARGET_HOST}"
  fi
fi

