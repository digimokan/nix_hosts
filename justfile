# vim: set filetype=just:

# ==========================================
# JUST CONFIGURATION
# ==========================================

set shell := ["bash", "-euo", "pipefail", "-c"]

# ==========================================
# GLOBAL VARIABLES
# ==========================================

repo_url := shell("git config --get remote.origin.url || echo 'https://github.com/digimokan/nix_hosts.git'")

nix_eval  := "nix --extra-experimental-features 'nix-command flakes' eval"
nix_shell := "nix --extra-experimental-features 'nix-command flakes' shell"
nix_run   := "nix --extra-experimental-features 'nix-command flakes' run"

sops_cmd := if shell("command -v sops >/dev/null 2>&1 && echo yes || echo no") == "yes" {
  "sops"
} else {
  nix_shell + " nixpkgs#sops --command sops"
}

jq_cmd := if shell("command -v jq >/dev/null 2>&1 && echo yes || echo no") == "yes" {
  "jq"
} else {
  nix_shell + " nixpkgs#jq --command jq"
}

# ==========================================
# PUBLIC RECIPES
# ==========================================

[doc("Show this help menu with full descriptions.")]
default:
  @just --list

[doc("Deploy directly to current machine. Example: just deploy-local tm1 wipe=yes")]
[linux]
deploy-local hostname wipe="no" prompt="no" : _require_root
  @trap 'just _cleanup_temp_files' EXIT; \
  echo "🚀 Initiating local deployment for {{hostname}}..."; \
  just _extract_host_key "{{hostname}}" "{{prompt}}"; \
  just _run_build_sequence "{{hostname}}" "{{wipe}}" "/tmp/nix_hosts_deploy_key.age"; \
  echo "✅ Local deployment finished."

[doc("Deploy to remote target over SSH. Example: just deploy-remote nas 192.168.1.50")]
deploy-remote hostname host_ip_addr wipe="no" reboot="yes":
  @trap 'just _cleanup_temp_files' EXIT; \
  echo "🚀 Initiating remote orchestration for {{hostname}} at {{host_ip_addr}}..."; \
  just _extract_host_key "{{hostname}}" "no"; \
  ssh_opts=(-o ControlMaster=auto -o ControlPath=/tmp/deploy_ssh_%h_%p_%r -o ControlPersist=10m); \
  echo "📦 Cloning repository on remote target..."; \
  ssh "${ssh_opts[@]}" "nixos@{{host_ip_addr}}" \
    "rm -rf /tmp/nix_hosts && git clone --single-branch --depth=1 '{{repo_url}}' /tmp/nix_hosts"; \
  echo "💉 Transferring SOPS keypair to remote temporary storage..."; \
  ssh "${ssh_opts[@]}" "nixos@{{host_ip_addr}}" "mkdir -p /tmp/secrets"; \
  scp "${ssh_opts[@]}" "/tmp/nix_hosts_deploy_key.age" "nixos@{{host_ip_addr}}:/tmp/secrets/host_keypair.age"; \
  echo "⚙️  Executing build sequence over SSH..."; \
  ssh "${ssh_opts[@]}" "nixos@{{host_ip_addr}}" \
    "sudo bash -c 'set -euo pipefail; cd /tmp/nix_hosts; \
    {{nix_shell}} nixpkgs#just --command just _run_build_sequence \
    \"{{hostname}}\" \"{{wipe}}\" \"/tmp/secrets/host_keypair.age\"; rm -rf /tmp/secrets'"; \
  if [ "{{reboot}}" = "yes" ]; then \
    echo "🔄 Rebooting remote target..."; \
    ssh "${ssh_opts[@]}" "nixos@{{host_ip_addr}}" "sudo reboot" || true; \
    echo "✅ Remote deployment finished. Target is rebooting."; \
  else \
    echo "✅ Remote deployment finished. Reboot into the newly-installed host."; \
  fi

[doc("Format encrypted ZFS user data pool. Example: just format-user-data-disk tm1 /dev/disk/x")]
[linux]
format-user-data-disk hostname +disks : \
    _require_root \
    (_validate_host_type hostname "user-facing")
  @echo -e "\n⚠️  WARNING: You are about to DESTROY ALL DATA on these disks: {{disks}}\n"
  @just _confirm_nuke
  @for disk in {{disks}}; do just _deep_wipe_disk "$disk"; done
  @just _execute_zpool_create "{{hostname}}" "user" "{{disks}}"

[doc("Format unencrypted ZFS server data pool. Example: just format-server-data-disk nas /dev/disk/x")]
[linux]
format-server-data-disk hostname +disks : \
    _require_root \
    (_validate_host_type hostname "server")
  @echo -e "\n⚠️  WARNING: You are about to DESTROY ALL DATA on these disks: {{disks}}\n"
  @just _confirm_nuke
  @for disk in {{disks}}; do just _deep_wipe_disk "$disk"; done
  @just _execute_zpool_create "{{hostname}}" "server" "{{disks}}"

[doc("Query Nix config and dynamically create missing ZFS datasets.")]
[linux]
create-datasets hostname : _require_root
  @just _create_zfs_datasets "{{hostname}}"

[doc("Aggressively nuke old partitions on disks defined in the host's Disko config.")]
[linux]
wipe-disks hostname : _require_root
  @just _wipe_target_disks "{{hostname}}"

[doc("Edit a SOPS file and automatically rekey all secrets.")]
edit-secret target_file:
  @if [ ! -f "{{target_file}}" ]; then echo "Error: Target file not found." >&2; exit 1; fi; \
  echo "📝 Opening {{target_file}} via SOPS..."; \
  {{sops_cmd}} "{{target_file}}"; \
  echo "🔄 Rekeying all YAML files in secrets/ directory..."; \
  for secret_file in secrets/*.yaml; do \
    if [ -f "$secret_file" ]; then \
      echo "   - Updating keys for $secret_file..."; \
      {{sops_cmd}} updatekeys -y "$secret_file" || echo "Warning: Failed to rekey $secret_file"; \
    fi; \
  done; \
  echo "✅ Secrets modification and rekey operations complete. Commit changes to Git."

# ==========================================
# PRIVATE RECIPES (Internal Logic)
# ==========================================

[private]
_require_root:
  @if [ "$(id -u)" -ne 0 ]; then \
    echo "Error: This operation requires root privileges. Please run with sudo." >&2; \
    exit 1; \
  fi

[private]
_cleanup_temp_files:
  @echo "🧹 Ensuring sensitive temporary files are purged..."
  -@rm -f /tmp/nix_hosts_deploy_key.age
  -@rm -f /tmp/nix_hosts_zfs_passphrase
  -@rm -f /tmp/nix_hosts_zdata.key

[private]
_confirm_nuke:
  @if [ -t 0 ]; then \
    read -r -p "Type 'NUKE' in all caps to confirm destruction: " confirm_wipe; \
    if [ "$confirm_wipe" != "NUKE" ]; then echo "Data format aborted by user." >&2; exit 1; fi; \
  else \
    echo "SSH Session detected. Proceeding automatically."; \
  fi

[private]
_validate_host_type hostname expected:
  @host_type=$({{nix_eval}} --raw ".#nixosConfigurations.{{hostname}}.config.custom.infrastructure.hostType"); \
  if [ "$host_type" != "{{expected}}" ]; then \
    echo "Safety abort: Host {{hostname}} is type '$host_type', expected '{{expected}}'." >&2; \
    exit 1; \
  fi

[private]
_query_nix_config hostname query apply="":
  @if [ -n "{{apply}}" ]; then \
    {{nix_eval}} --raw ".#nixosConfigurations.{{hostname}}.config.{{query}}" --apply "{{apply}}"; \
  else \
    {{nix_eval}} --raw ".#nixosConfigurations.{{hostname}}.config.{{query}}"; \
  fi

[private]
_get_sops_secret secret_key file_path:
  @if [ ! -f "{{file_path}}" ]; then exit 0; fi; \
  {{sops_cmd}} -d --extract "[\"{{secret_key}}\"]" "{{file_path}}" 2>/dev/null || true

[private]
_extract_host_key hostname prompt="no":
  @if [ "{{prompt}}" = "yes" ]; then \
    echo "🔒 LOCAL DEPLOYMENT DETECTED 🔒" >&2; \
    read -r -s -p "Enter Age Master Key: " RAW_INPUT < /dev/tty; \
    echo "" >&2; \
    if [[ "$RAW_INPUT" == AGE-SECRET-KEY-* ]]; then \
      export SOPS_AGE_KEY="$RAW_INPUT"; \
    else \
      export SOPS_AGE_KEY="AGE-SECRET-KEY-$RAW_INPUT"; \
    fi; \
    if [ "${#SOPS_AGE_KEY}" -ne 74 ]; then echo "Error: Invalid key length." >&2; exit 1; fi; \
  fi; \
  echo "🔐 Attempting to extract pure-Age keypair for host '{{hostname}}'..." >&2; \
  secrets_file="secrets/master_secrets.yaml"; \
  if [ ! -f "$secrets_file" ]; then echo "Error: Admin vault not found" >&2; exit 1; fi; \
  key_value=$(just _get_sops_secret "age_keypair_host_{{hostname}}" "$secrets_file"); \
  if [ -n "${SOPS_AGE_KEY:-}" ]; then \
    unset SOPS_AGE_KEY; \
    echo "🧹 Master key purged from active memory." >&2; \
  fi; \
  if [ -z "$key_value" ]; then echo "Error: Could not find keypair" >&2; exit 1; fi; \
  echo "$key_value" > "/tmp/nix_hosts_deploy_key.age"; \
  chmod 600 "/tmp/nix_hosts_deploy_key.age"; \
  echo "✅ Host keypair extracted successfully." >&2

[private]
_extract_zfs_passphrase hostname:
  @secrets_file="secrets/{{hostname}}_host_secrets.yaml"; \
  if [ ! -f "$secrets_file" ]; then exit 0; fi; \
  host_type=$(just _query_nix_config "{{hostname}}" "custom.infrastructure.hostType"); \
  if [ "$host_type" != "user-facing" ]; then exit 0; fi; \
  echo "🔑 Extracting plaintext ZFS passphrase for deployment..." >&2; \
  pass_value=$(just _get_sops_secret "{{hostname}}_host_zfs_encryption_passphrase" "$secrets_file"); \
  if [ -z "$pass_value" ]; then echo "Failed to extract passphrase." >&2; exit 1; fi; \
  echo -n "$pass_value" > "/tmp/nix_hosts_zfs_passphrase"

[private]
_inject_sops_host_keypair_to_mnt key_path:
  @echo "💉 Injecting SOPS host keypair into the newly formatted volume (/mnt)..."
  @mkdir -p /mnt/var/lib/sops-nix
  @cp "{{key_path}}" /mnt/var/lib/sops-nix/host_keypair.age
  @chmod 400 /mnt/var/lib/sops-nix/host_keypair.age
  @echo "✅ SOPS keypair injected successfully."

[private]
_inject_zdata_key_to_mnt hostname:
  @secrets_file="secrets/{{hostname}}_host_secrets.yaml"; \
  if [ ! -f "$secrets_file" ]; then exit 0; fi; \
  echo "🔑 Checking for persistent zdata key in SOPS..."; \
  hex_key=$(just _get_sops_secret "{{hostname}}_host_zfs_zdata_encryption_symkey" "$secrets_file" || true); \
  if [ -n "$hex_key" ]; then \
    echo "   - Key found. Injecting into /mnt/persist/zfs-keys..."; \
    mkdir -p /mnt/persist/zfs-keys; \
    echo -n "$hex_key" > "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"; \
    chmod 400 "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"; \
    echo "✅ Zdata hex key injected successfully."; \
  fi

[private]
_emplace_target_hostid hostname:
  @echo "🧬 Extracting target hostId to prevent ZFS import mismatch..."
  @target_hostid=$(just _query_nix_config "{{hostname}}" "networking.hostId"); \
  if [ -z "$target_hostid" ]; then echo "Error: Could not extract hostId" >&2; exit 1; fi; \
  rm -f /etc/hostid; \
  zgenhostid "$target_hostid"; \
  echo "✅ Installer hostId temporarily assumed as $target_hostid."

[private]
_deep_wipe_partition part:
  @echo "   - Erasing signatures on {{part}}..."
  -@mdadm --zero-superblock --force "{{part}}" 2>/dev/null
  -@zpool labelclear -f "{{part}}" 2>/dev/null
  -@wipefs -a -f "{{part}}" 2>/dev/null

[private]
_deep_wipe_disk disk:
  @echo "☢️  Nuking {{disk}}..."
  -@for part in $(lsblk -plno NAME "{{disk}}" 2>/dev/null | sort -r); do \
    if [ "$part" != "{{disk}}" ]; then just _deep_wipe_partition "$part"; fi; \
  done
  -@blkdiscard -f "{{disk}}" 2>/dev/null
  -@mdadm --zero-superblock --force "{{disk}}" 2>/dev/null
  -@zpool labelclear -f "{{disk}}" 2>/dev/null
  -@wipefs -a -f "{{disk}}" 2>/dev/null
  -@sgdisk --zap-all "{{disk}}" >/dev/null 2>&1
  -@partprobe "{{disk}}" 2>/dev/null
  @sleep 2

[private]
_wipe_target_disks hostname:
  @echo "🛡️  Validating safety constraints for disk wipe..."
  @if ! command -v nixos-install &> /dev/null; then \
    echo "Safety abort: 'nixos-install' not found. You are not on Live ISO." >&2; exit 1; \
  fi; \
  echo "🔍 Querying flake configuration for target disks..."; \
  nix_apply='x: builtins.concatStringsSep "\n" (builtins.map (d: d.device) (builtins.attrValues x))'; \
  raw_disk_output=$(just _query_nix_config "{{hostname}}" "disko.devices.disk" "$nix_apply"); \
  target_disks=(); \
  while IFS= read -r disk; do \
    if [[ -n "$disk" && "$disk" == /dev/* ]]; then target_disks+=("$disk"); fi; \
  done <<< "$raw_disk_output"; \
  if [ "${#target_disks[@]}" -eq 0 ]; then \
    echo "No target disks found in Disko configuration. Cannot proceed." >&2; exit 1; \
  fi; \
  echo -e "\n⚠️  WARNING: You are about to DESTROY ALL DATA on EXPLICITLY TARGETED disks:"; \
  for disk in "${target_disks[@]}"; do echo "   -> $disk"; done; echo ""; \
  if [ -t 0 ]; then \
    read -r -p "Type 'WIPE' in all caps to confirm destruction: " confirm_wipe; \
    if [ "$confirm_wipe" != "WIPE" ]; then echo "Wipe aborted." >&2; exit 1; fi; \
  else \
    echo "SSH Session detected. Proceeding with targeted wipe."; \
  fi; \
  echo "🧹 Tearing down active mounts and volumes system-wide..."; \
  swapoff -a 2>/dev/null || true; \
  umount -R /mnt 2>/dev/null || true; \
  zfs unmount -a 2>/dev/null || true; \
  zpool export -f -a 2>/dev/null || true; \
  dmsetup remove_all -f 2>/dev/null || true; \
  vgchange -an 2>/dev/null || true; \
  mdadm --stop --scan 2>/dev/null || true; \
  for disk in "${target_disks[@]}"; do just _deep_wipe_disk "$disk"; done; \
  echo "✅ Targeted wipe sequence complete."

[private]
_create_zfs_datasets hostname:
  @echo "📂 Querying Nix config for required ZFS datasets..."
  @json_data=$({{nix_eval}} --json ".#nixosConfigurations.{{hostname}}.config.custom.system.zfs.storagePools"); \
  ds_paths=$(echo "$json_data" | {{jq_cmd}} -r \
    '.[] as $pool | $pool.datasets[] as $ds | ($pool.poolName + "/" + $ds.baseDataset)'); \
  for ds_path in $ds_paths; do \
    if zfs list "$ds_path" >/dev/null 2>&1; then \
      echo "   - Dataset $ds_path already exists. Skipping."; \
    else \
      echo "   - Creating dataset: $ds_path"; \
      zfs create -o mountpoint=legacy "$ds_path"; \
    fi; \
  done; \
  echo "✅ ZFS dataset creation complete."

[private]
_execute_zpool_create hostname format_type disks:
  @trap 'just _cleanup_temp_files' EXIT; \
  disk_array=({{disks}}); \
  pool_name="zdata_{{hostname}}"; \
  pool_mode=""; \
  if [ "${#disk_array[@]}" -eq 2 ]; then pool_mode="mirror"; fi; \
  compat_val=$(just _query_nix_config "{{hostname}}" "disko.devices.zpool.zroot.options.compatibility"); \
  compat_flag=""; \
  if [ -n "$compat_val" ]; then compat_flag="-o compatibility=$compat_val"; fi; \
  enc_flags=""; \
  if [ "{{format_type}}" = "user" ]; then \
    hex_key=$({{sops_cmd}} -d --extract "[\"{{hostname}}_host_zfs_zdata_encryption_symkey\"]" \
      "secrets/{{hostname}}_host_secrets.yaml" 2>/dev/null); \
    if [ -z "$hex_key" ]; then echo "Failed to extract data disk encryption key." >&2; exit 1; fi; \
    echo -n "$hex_key" > "/tmp/nix_hosts_zdata.key"; \
    enc_flags="-O encryption=aes-256-gcm -O keyformat=hex -O keylocation=file:///tmp/nix_hosts_zdata.key"; \
  fi; \
  zpool create -o ashift=12 $compat_flag \
    -O compression=lz4 -O xattr=sa -O acltype=posixacl -O atime=off \
    $enc_flags -m none "$pool_name" $pool_mode "${disk_array[@]}"; \
  just _create_zfs_datasets "{{hostname}}"; \
  zpool export "$pool_name"; \
  echo "✅ {{format_type}} data drive formatted successfully."

[private]
_conditional_wipe hostname wipe:
  @if [ "{{wipe}}" = "yes" ]; then just _wipe_target_disks "{{hostname}}"; fi

[private]
_execute_disko_format hostname:
  @trap 'just _cleanup_temp_files' EXIT; \
  echo "⚙️  Formatting disks via Disko..."; \
  just _extract_zfs_passphrase "{{hostname}}"; \
  {{nix_run}} "github:nix-community/disko" -- --mode format --flake ".#{{hostname}}"; \
  echo "⏳ Waiting for USB enclosure block devices to settle..."; \
  udevadm settle; \
  echo "✅ Disko formatting complete."; \
  echo "⚙️  Mounting disks to /mnt via Disko..."; \
  {{nix_run}} "github:nix-community/disko" -- --mode mount --flake ".#{{hostname}}"; \
  echo "✅ Disko mounting complete."

[private]
_execute_nixos_install hostname:
  @echo "🚀 Installing NixOS to /mnt..."
  @nixos-install --flake ".#{{hostname}}" --no-root-passwd
  @echo "✅ NixOS installation complete."

[private]
_run_build_sequence hostname wipe key_file : \
    (_emplace_target_hostid hostname) \
    (_conditional_wipe hostname wipe) \
    (_execute_disko_format hostname) \
    (_inject_sops_host_keypair_to_mnt key_file) \
    (_inject_zdata_key_to_mnt hostname) \
    (_execute_nixos_install hostname)
  @echo "✅ Build sequence for {{hostname}} complete."

