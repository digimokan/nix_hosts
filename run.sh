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
  --deploy-local         Execute deployment directly on the current machine.
                         (Requires running from the NixOS Live ISO).
  --deploy-remote        Execute deployment on a remote target over SSH.
                         (Requires the -R/--remote option).
  -w, --wipe-disks       Aggressively nuke old partitions and labels.
                         SAFETY: Only executes on disks defined in the host's Disko config.
  -e, --edit-secret FILE Edit a SOPS file and automatically rekey all secrets.
  -h, --help             Show this help menu and exit

OPTIONS:
  -T, --target HOST      (Required for deploy) The NixOS configuration name (e.g., nas)
  -R, --remote IP        (Required for --deploy-remote) Target IP address
  -p, --prompt-key       (Optional for --deploy-local) Securely prompt for the Age Master Key
  -N, --no-reboot-remote (Optional for --deploy-remote) Do not reboot after deployment

EXAMPLES:
  Local Deploy  (run on minimal ISO): sudo ./$(basename "${0}") --deploy-local -p -w -T nas
  Remote Deploy (SSH to minimal ISO):      ./$(basename "${0}") --deploy-remote -w -T nas -R 192.168.1.50
  Local Wipe    (run on minimal ISO): sudo ./$(basename "${0}") -w -T nas
  Edit Secret   (run on dev machine):      ./$(basename "${0}") -e secrets/admin_secrets.yaml
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
     [ -z "${EDIT_SECRET_FILE}" ]; then
    errmsg="You must specify a command:"
    errmsg="${errmsg} --deploy-local,"
    errmsg="${errmsg} --deploy-remote,"
    errmsg="${errmsg} -w/--wipe-disks,"
    errmsg="${errmsg} -e/--edit-secret."
    die "${errmsg}"
  fi

  if [ -n "${DEPLOY_MODE}" ]; then
    if [ -z "${TARGET_HOST}" ]; then
      die "The -T/--target option is required for deployment."
    fi
    if [ "${DEPLOY_MODE}" = "remote" ] && [ -z "${REMOTE_IP}" ]; then
      die "The -R/--remote option is required when using --deploy-remote."
    fi
  fi
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

  local secrets_file="secrets/admin_secrets.yaml"
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

inject_key_to_mnt() {
  local key_path="${1}"
  echo "💉 Injecting SOPS host keypair into the newly formatted volume (/mnt)..."
  mkdir -p /mnt/var/lib/sops-nix
  cp "${key_path}" /mnt/var/lib/sops-nix/host_keypair.age
  chmod 400 /mnt/var/lib/sops-nix/host_keypair.age
  echo "✅ SOPS keypair injected successfully."
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
  raw_disk_output=$(nix --extra-experimental-features "nix-command flakes" eval --raw "${nix_query}" --apply "${nix_apply}" 2>/dev/null || true)

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
    echo "☢️ Nuking ${disk}..."
    blkdiscard -f "${disk}" 2>/dev/null || echo "     Warning: blkdiscard failed or is unsupported. Proceeding to software wipe..."
    wipefs -a -f "${disk}" 2>/dev/null || true
    sgdisk --zap-all "${disk}" >/dev/null 2>&1 || true
    partprobe "${disk}" 2>/dev/null || echo "     Warning: partprobe failed. The kernel is locked. A reboot is recommended."
    sleep 2
  done
  echo "✅ Targeted wipe sequence complete."
}

emplace_target_hostid() {
  local target="${1}"

  echo "🧬 Extracting target hostId to prevent ZFS import mismatch..."
  local target_hostid
  target_hostid=$(nix --extra-experimental-features "nix-command flakes" eval --raw ".#nixosConfigurations.${target}.config.networking.hostId")

  if [ -z "${target_hostid}" ]; then
    die "Could not extract networking.hostId for '${target}'."
  fi

  # The Live ISO symlinks /etc/hostid to the read-only Nix store.
  # Remove the symlink and write the target's hostId to the RAM overlay filesystem.
  rm -f /etc/hostid
  zgenhostid "${target_hostid}"
  echo "✅ Installer hostId temporarily assumed as ${target_hostid}."
}

execute_disko_format() {
  local target="${1}"
  echo "⚙️ Formatting disks and mounting to /mnt via Disko..."

  # Run pure disko (formats and mounts, does NOT install NixOS)
  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko" -- --mode disko --flake ".#${target}"

  echo "✅ Disko formatting complete."
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
  inject_key_to_mnt "${key_file}"
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
  elif [ "${DEPLOY_MODE}" = "remote" ]; then
    deploy_remote
  elif [ "${DEPLOY_MODE}" = "local" ]; then
    deploy_local
  elif [ "${WIPE_DISKS}" = "yes" ]; then
    if [ "${EUID}" -ne 0 ]; then
      die "Wiping disks requires root privileges. Please run with sudo."
    fi
    wipe_target_disks "${TARGET_HOST}"
  fi
fi

