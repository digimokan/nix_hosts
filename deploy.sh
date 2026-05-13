#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
DEFAULT_REPO_URL="https://github.com/digimokan/nix_hosts.git"

# --- Globals ---
TARGET_HOST=""
REMOTE_IP=""
REPO_URL="${DEFAULT_REPO_URL}"
DEPLOY_MODE="local"
WIPE_DISKS="no"
REBOOT_REMOTE="yes"

# ==========================================
# Utility Functions
# ==========================================

die() {
  printf "Error: %s\n" "${1}" >&2
  exit 1
}

print_usage() {
  cat <<EOF
USAGE: $(basename "${0}") [OPTIONS]

PURPOSE:
  * Format disks via Disko, deploy NixOS, and securely inject pure-Age SOPS keys.
  * For remote deployments, the orchestrating machine decrypts the host keypair
    locally and securely transfers it to the target over SSH.

OPTIONS:
  -t, --target HOST      (Required) The NixOS configuration name (e.g., nas)
  -r, --remote IP        (Optional) Deploy remotely to the target IP address
  -u, --url URL          (Optional) Git repository URL to clone on remote target
                         Default: ${DEFAULT_REPO_URL}
  -w, --wipe-disks       (Optional) Aggressively nuke old partitions and labels
                         SAFETY: Only executes on disks defined in the host's Disko config.
  -n, --no-reboot-remote (Optional) Do NOT reboot the remote machine after deployment
  -h, --help             Show this help menu and exit

EXAMPLES:
  Local Deploy  (run on minimal ISO): sudo ./$(basename "${0}") -t nas -w
  Remote Deploy (SSH to minimal ISO):      ./$(basename "${0}") -t nas -w -r 192.168.1.50
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
  key_value=$(eval "${sops_cmd} -d '${secrets_file}'" | awk -v target="age_keypair_host_${TARGET_HOST}:" '
    $0 ~ target {flag=1; next}
    flag && /^[[:space:]]/ {print; next}
    flag && /^[^[:space:]]/ {flag=0}
  ')

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

  # 1. Define the Nix query string
  local nix_query=".#nixosConfigurations.${target}.config.disko.devices.disk"

  # 2. Define the apply function. We extract the 'device' string from each disk entry.
  local nix_apply='x: builtins.concatStringsSep "\n" (builtins.map (d: d.device) (builtins.attrValues x))'

  # 3. Execute the query with experimental features enabled
  local raw_disk_output
  raw_disk_output=$(nix --extra-experimental-features "nix-command flakes" eval --raw "${nix_query}" --apply "${nix_apply}" 2>/dev/null || true)

  # 4. Read the output into an array
  local target_disks=()
  while IFS= read -r disk; do
    # Only add non-empty strings that look like device paths (e.g., start with /dev/)
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

execute_disko_format() {
  local target="${1}"
  echo "⚙️ Formatting disks and mounting to /mnt via Disko..."

  # Run pure disko (formats and mounts, does NOT install NixOS)
  nix --extra-experimental-features "nix-command flakes" \
    run "github:nix-community/disko -- --mode disko .#${target}"
}

execute_nixos_install() {
  local target="${1}"
  echo "🚀 Installing NixOS to /mnt..."
  # Note: do not have installer prompt to set initial root password
  nixos-install --flake ".#${target}" --no-root-passwd
}

# This function contains the actual build steps, meant to run on the target host
run_build_sequence() {
  local target="${1}"
  local do_wipe="${2}"
  local key_file="${3}"

  if [ "${EUID}" -ne 0 ]; then
    die "Build sequence requires root privileges."
  fi

  if [ "${do_wipe}" = "yes" ]; then
    wipe_target_disks "${target}"
  fi

  execute_disko_format "${target}"
  inject_key_to_mnt "${key_file}"
  execute_nixos_install "${target}"
}

deploy_local() {
  echo "🚀 Initiating local deployment for ${TARGET_HOST}..."

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

    source ./deploy.sh ""
    run_build_sequence "${local_target}" "${local_wipe}" "/tmp/secrets/host_keypair.age"
    rm -rf /tmp/secrets
EOF
  echo "✅ Build sequence executed successfully."

  if [ "${REBOOT_REMOTE}" = "yes" ]; then
    echo "🔄 Rebooting remote target..."
    ssh "${ssh_opts[@]}" "nixos@${REMOTE_IP}" "sudo reboot" || true
    echo "✅ Remote deployment finished. Target is rebooting."
  else
    echo "✅ Remote deployment finished. Reboot into the newly-installed host."
  fi
}

# ==========================================
# Main Entry Point
# ==========================================

# Only execute main if the script is run directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  parse_args "${@}"

  if [ "${DEPLOY_MODE}" = "remote" ]; then
    deploy_remote
  else
    deploy_local
  fi
fi

