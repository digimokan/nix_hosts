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

host_keypair_tempfile_path := "/tmp/nix_hosts_host_keypair.age"
host_zroot_passphrase_tempfile_path := "/tmp/nix_hosts_zfs_zroot_passphrase"
host_zdata_keystring_tempfile_path := "/tmp/nix_hosts_zfs_zdata_keystring"

# ==========================================
# PUBLIC RECIPES
# ==========================================

[private]
[doc("Show the list of public recipes with their doc() comments.")]
default:
  @just --list --unsorted

[doc("Deploy NixOS to a local or remote host.\n  Ex: just deploy hostname=nas\n  Ex: just deploy hostname=nas host_ip=192.168.1.50")]
deploy hostname host_ip="" prompt_for_master_secret="no": _require_root
  @just _deploy_internal hostname="{{hostname}}" host_ip="{{host_ip}}" \
    prompt_for_master_secret="{{prompt_for_master_secret}}" || { just _cleanup_temp_files; exit 1; }
  @just _cleanup_temp_files

[doc("Wipe and format the hosts zdata pool on its data disks.\n  Ex: just format-data-disks hostname=tm1")]
format-data-disks hostname host_ip="": _require_root
  @just _format_data_disks_internal hostname="{{hostname}}" host_ip="{{host_ip}}" \
    || { just _cleanup_temp_files; exit 1; }
  @just _cleanup_temp_files

[doc("Create all missing ZFS datasets on the host's zdata pool.\n  Ex: just create-datasets hostname=tm1")]
create-datasets hostname host_ip="": _require_root
  @just _create_zfs_datasets hostname="{{hostname}}" host_ip="{{host_ip}}"

[doc("Edit a SOPS file and automatically rekey all secrets.\n  Ex: just edit-secret target_file=secrets/admin.yaml")]
edit-secret target_file:
  #!/usr/bin/env bash
  set -euo pipefail
  just _runtime_assert condition='[ -f "{{target_file}}" ]' exit_msg="Target file not found."
  echo "📝 Opening {{target_file}} via SOPS..."
  {{sops_cmd}} "{{target_file}}"
  just _rekey_all_sops_secrets_files

# ==========================================
# PRIVATE RECIPES (Internal Logic)
# ==========================================

[private]
[doc("Ensure the user is running as root.")]
_require_root:
  @just _runtime_assert condition='[ "$(id -u)" -eq 0 ]' exit_msg="This operation requires sudo."

[private]
[doc("Evaluate a bash conditional and exit loudly with a custom message if it fails.")]
_runtime_assert condition exit_msg:
  @if ! eval {{condition}}; then echo "Error: {{exit_msg}}" >&2; exit 1; fi

[private]
[doc("Execute a command silently, ignoring any errors or output.")]
_exec_silent_ignore_errs cmd:
  @bash -c "{{cmd}}" >/dev/null 2>&1 || true

[private]
[doc("Purge sensitive files. Used safely via logical OR short-circuits in public recipes.")]
_cleanup_temp_files:
  @echo "🧹 Ensuring sensitive temporary files are purged..."
  @just _exec_silent_ignore_errs cmd="rm -f {{host_keypair_tempfile_path}}"
  @just _exec_silent_ignore_errs cmd="rm -f {{host_zroot_passphrase_tempfile_path}}"
  @just _exec_silent_ignore_errs cmd="rm -f {{host_zdata_keystring_tempfile_path}}"

[private]
[doc("Query Nix config. Asserts value exists.")]
_query_nix_config hostname query nix_apply_expr="":
  #!/usr/bin/env bash
  set -euo pipefail
  apply_arg=$([ -n "{{nix_apply_expr}}" ] && echo "--apply \"{{nix_apply_expr}}\"" || echo "")
  result=$(eval "{{nix_eval}} --raw \".#nixosConfigurations.{{hostname}}.config.{{query}}\" ${apply_arg}")
  just _runtime_assert condition="[ -n \"\${result}\" ]" exit_msg="Nix query {{query}} returned empty/null."
  echo -n "${result}"

[private]
[doc("Extract a secret from SOPS. Asserts file exists and secret is not empty.")]
_get_sops_secret secret_key file_path:
  #!/usr/bin/env bash
  set -euo pipefail
  just _runtime_assert condition='[ -f "{{file_path}}" ]' exit_msg="Could not find {{file_path}}"
  secret_val=$({{sops_cmd}} -d --extract "[\"{{secret_key}}\"]" "{{file_path}}")
  just _runtime_assert condition="[ -n \"\${secret_val}\" ]" exit_msg="Could not find {{secret_key}} in {{file_path}}"
  echo -n "${secret_val}"

[private]
[doc("Iterate through all SOPS YAML files and rekey them.")]
_rekey_all_sops_secrets_files:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🔄 Rekeying all YAML files in secrets/ directory..."
  for secret_file in secrets/*.yaml; do
    if [ -f "${secret_file}" ]; then
      echo "   - Updating keys for ${secret_file}..."
      {{sops_cmd}} updatekeys -y "${secret_file}"
    fi
  done
  @echo "✅ Secrets modification and rekey operations complete. Commit changes to Git."

[private]
[doc("Execute a command over SSH on the target installer environment.")]
_ssh_to_installer host_ip cmd:
  @ssh -o ControlMaster=auto -o ControlPath=/tmp/deploy_ssh_%h_%p_%r -o ControlPersist=10m \
    "nixos@{{host_ip}}" "set -euo pipefail; {{cmd}}"

[private]
[doc("Transfer a file over SCP to the target installer environment.")]
_scp_to_installer host_ip local_path remote_path:
  @scp -o ControlMaster=auto -o ControlPath=/tmp/deploy_ssh_%h_%p_%r -o ControlPersist=10m \
    "{{local_path}}" "nixos@{{host_ip}}:{{remote_path}}"

[private]
[doc("Silent boolean check for host type.")]
_host_type_is hostname expected_type:
  #!/usr/bin/env bash
  set -euo pipefail
  host_type=$(just _query_nix_config hostname="{{hostname}}" query="custom.infrastructure.hostType")
  if [ "${host_type}" = "{{expected_type}}" ]; then exit 0; else exit 1; fi

# ==========================================
# ORCHESTRATION ROUTING & DEPLOYMENT
# ==========================================

[private]
[doc("Route deployment to local execution or remote execution based on auto-detection.")]
_deploy_internal hostname host_ip prompt_for_master_secret:
  #!/usr/bin/env bash
  set -euo pipefail
  local_host="$(hostname)"
  if [ "${local_host}" = "nixos" ] || [ "${local_host}" = "{{hostname}}" ]; then
    just _deploy_local hostname="{{hostname}}" prompt_for_master_secret="{{prompt_for_master_secret}}"
  else
    just _runtime_assert condition='[ -n "{{host_ip}}" ]' exit_msg="Remote deploy requires host_ip parameter."
    just _deploy_remote hostname="{{hostname}}" host_ip="{{host_ip}}"
  fi

[private]
[doc("Execute local deployment orchestration.")]
_deploy_local hostname prompt_for_master_secret:
  @echo "🚀 Initiating local deployment for {{hostname}}..."
  @just _query_sops_for_host_age_keypair hostname="{{hostname}}" \
    prompt_for_master_secret="{{prompt_for_master_secret}}"
  @just _run_build_sequence hostname="{{hostname}}"
  @echo "✅ Local deployment finished."

[private]
[doc("Execute remote deployment orchestration over SSH.")]
_deploy_remote hostname host_ip:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🚀 Initiating remote orchestration for {{hostname}} at {{host_ip}}..."
  just _query_sops_for_host_age_keypair hostname="{{hostname}}" prompt_for_master_secret="no"
  echo "📦 Preparing remote temporary storage..."
  just _ssh_to_installer host_ip="{{host_ip}}" cmd="rm -rf /tmp/nix_hosts {{host_keypair_tempfile_path}}"
  echo "📦 Cloning repository on remote target..."
  just _ssh_to_installer host_ip="{{host_ip}}" \
    cmd="git clone --single-branch --depth=1 '{{repo_url}}' /tmp/nix_hosts"
  echo "💉 Transferring SOPS keypair to remote temporary storage..."
  just _scp_to_installer host_ip="{{host_ip}}" local_path="{{host_keypair_tempfile_path}}" \
    remote_path="{{host_keypair_tempfile_path}}"
  echo "⚙️  Executing build sequence over SSH..."
  just _ssh_to_installer host_ip="{{host_ip}}" \
    cmd="cd /tmp/nix_hosts && {{nix_shell}} nixpkgs#just --command just _run_build_sequence \
    hostname=\"{{hostname}}\" && rm -f {{host_keypair_tempfile_path}}"
  echo "🔄 Remote deployment finished. Target must be manually rebooted into new OS."

# ==========================================
# SECRETS EXTRACTION & INJECTION
# ==========================================

[private]
[doc("Extract the Age keypair from the master SOPS vault.")]
_query_sops_for_host_age_keypair hostname prompt_for_master_secret="no":
  #!/usr/bin/env bash
  set -euo pipefail
  if [ "{{prompt_for_master_secret}}" = "yes" ]; then
    read -r -s -p "74-Char Master Key: " RAW_INPUT < /dev/tty
    echo "" >&2
    if [ "${RAW_INPUT:0:15}" = "AGE-SECRET-KEY-" ]; then
      export SOPS_AGE_KEY="${RAW_INPUT}"
    else
      export SOPS_AGE_KEY="AGE-SECRET-KEY-${RAW_INPUT}"
    fi
    just _runtime_assert condition='[ "${#SOPS_AGE_KEY}" -eq 74 ]' exit_msg="Invalid key length."
  fi
  echo "🔐 Attempting to extract Age keypair for host '{{hostname}}'..." >&2
  key_value=$(just _get_sops_secret secret_key="age_keypair_host_{{hostname}}" \
    file_path="secrets/master_secrets.yaml")
  if [ -n "${SOPS_AGE_KEY:-}" ]; then unset SOPS_AGE_KEY; echo "🧹 Master key purged." >&2; fi
  echo "${key_value}" > "{{host_keypair_tempfile_path}}"
  chmod 600 "{{host_keypair_tempfile_path}}"
  echo "✅ Target host Age keypair successfully extracted to orchestration machine tempfile" >&2

[private]
[doc("Extract plaintext ZFS passphrase to feed to Disko for user-facing hosts.")]
_extract_zfs_zroot_passphrase_for_user_facing_host hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! just _host_type_is hostname="{{hostname}}" expected_type="user-facing"; then exit 0; fi
  echo "🔑 Extracting plaintext ZFS passphrase for deployment..." >&2
  pass_value=$(just _get_sops_secret \
    secret_key="{{hostname}}_host_zfs_zroot_encryption_passphrase" \
    file_path="secrets/{{hostname}}_host_secrets.yaml")
  echo -n "${pass_value}" > "{{host_zroot_passphrase_tempfile_path}}"

[private]
[doc("Inject the SOPS host keypair into the newly mounted root filesystem.")]
_inject_sops_host_keypair_to_zroot_mnt:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "💉 Injecting SOPS host keypair into the newly formatted volume (/mnt)..."
  mkdir -p /mnt/var/lib/sops-nix
  cp "{{host_keypair_tempfile_path}}" /mnt/var/lib/sops-nix/host_keypair.age
  chmod 400 /mnt/var/lib/sops-nix/host_keypair.age
  echo "✅ SOPS keypair injected successfully."

[private]
[doc("Inject ZFS zdata encryption keystring to enable auto-unlocking on boot for user-facing hosts.")]
_inject_zdata_key_to_zroot_mnt_for_user_facing_host hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! just _host_type_is hostname="{{hostname}}" expected_type="user-facing"; then exit 0; fi
  echo "🔑 Inject ZFS zdata encryption keystring to target host's zroot /mnt/persist/zfs-keys..."
  zdata_encryption_keystring=$(just _get_sops_secret \
    secret_key="{{hostname}}_host_zfs_zdata_encryption_symkey" \
    file_path="secrets/{{hostname}}_host_secrets.yaml")
  mkdir -p /mnt/persist/zfs-keys
  echo -n "${zdata_encryption_keystring}" > "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"
  chmod 400 "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"
  echo "✅ Zdata encryption keystring injected successfully."

[private]
[doc("Extract and emplace the networking.hostId to prevent ZFS import mismatch issues.")]
_emplace_target_hostid hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🧬 Extracting target hostId to prevent ZFS import mismatch..."
  target_hostid=$(just _query_nix_config hostname="{{hostname}}" query="networking.hostId")
  rm -f /etc/hostid
  zgenhostid "${target_hostid}"
  echo "✅ Installer hostId temporarily assumed as ${target_hostid}."

# ==========================================
# DISK WIPING & ZFS MANAGEMENT
# ==========================================

[private]
[doc("Deeply wipe all partitions and labels from a single block device.")]
_deep_wipe_disk disk host_ip="":
  #!/usr/bin/env bash
  set -euo pipefail
  echo "☢️  Nuking {{disk}}..."
  wipe_script='
    silent_exec() { bash -c "$1" >/dev/null 2>&1 || true; }
    for part in $(lsblk -plno NAME "{{disk}}" 2>/dev/null | sort -r); do
      if [ "$part" != "{{disk}}" ]; then
        echo "   - Erasing signatures on $part..."
        silent_exec "mdadm --zero-superblock --force \"$part\""
        silent_exec "zpool labelclear -f \"$part\""
        silent_exec "wipefs -a -f \"$part\""
      fi
    done
    silent_exec "blkdiscard -f \"{{disk}}\""
    silent_exec "mdadm --zero-superblock --force \"{{disk}}\""
    silent_exec "zpool labelclear -f \"{{disk}}\""
    silent_exec "wipefs -a -f \"{{disk}}\""
    silent_exec "sgdisk --zap-all \"{{disk}}\""
    silent_exec "partprobe \"{{disk}}\""
  '
  if [ -n "{{host_ip}}" ]; then
    just _ssh_to_installer host_ip="{{host_ip}}" cmd="${wipe_script}"
  else
    bash -c "${wipe_script}"
  fi
  sleep 2

[private]
[doc("Validate and wipe all OS disks associated with the target host in the Disko config.")]
_wipe_zroot_os_disks hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "Wiping zroot OS disks..."
  nix_apply='x: builtins.concatStringsSep " " (builtins.map (d: d.device) (builtins.attrValues x))'
  target_disks=$(just _query_nix_config hostname="{{hostname}}" query="disko.devices.disk" \
    nix_apply_expr="${nix_apply}")
  echo "🧹 Tearing down active OS mounts and volumes..."
  just _exec_silent_ignore_errs cmd="swapoff -a"
  just _exec_silent_ignore_errs cmd="umount -R /mnt"
  just _exec_silent_ignore_errs cmd="zfs unmount -a"
  just _exec_silent_ignore_errs cmd="zpool export -f -a"
  just _exec_silent_ignore_errs cmd="dmsetup remove_all -f"
  just _exec_silent_ignore_errs cmd="vgchange -an"
  just _exec_silent_ignore_errs cmd="mdadm --stop --scan"
  for disk in ${target_disks}; do
    just _deep_wipe_disk disk="${disk}"
  done
  echo "✅ Wipe of zroot OS disks complete."

[private]
[doc("Parse the Nix JSON config to extract required baseDatasets and create them with legacy mountpoints.")]
_create_zfs_datasets hostname host_ip="":
  #!/usr/bin/env bash
  set -euo pipefail
  echo "📂 Querying Nix config and creating required ZFS datasets on zdata disks..."
  json_data=$({{nix_eval}} --json \
    ".#nixosConfigurations.{{hostname}}.config.custom.system.zfs.storagePools")
  ds_paths=$(echo "${json_data}" | {{jq_cmd}} -r \
    '.[] as $pool | $pool.datasets[] as $ds | ($pool.poolName + "/" + $ds.baseDataset)')
  for ds_path in ${ds_paths}; do
    cmd="if zfs list \"${ds_path}\" >/dev/null 2>&1; then \
      echo \"   - Dataset ${ds_path} already exists.\"; \
      else zfs create -o mountpoint=legacy \"${ds_path}\" && echo \"   - Created: ${ds_path}\"; fi"
    if [ -n "{{host_ip}}" ]; then
      just _ssh_to_installer host_ip="{{host_ip}}" cmd="${cmd}"
    else
      bash -c "${cmd}"
    fi
  done
  echo "✅ ZFS dataset creation complete."

[private]
[doc("Verify disk topology visually before formatting.")]
_verify_data_disk_topology hostname host_ip target_disks:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -e "\n⚠️  TARGET TOPOLOGY VERIFICATION:"
  verify_script='
    echo "--- All Disks on System ---"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
    echo -e "\n--- Target Disks for zdata Pool ---"
    for d in {{target_disks}}; do
      ls -l /dev/disk/by-id/ | grep "$(basename "$d")" || true
    done
  '
  local_host="$(hostname)"
  if [ "${local_host}" = "nixos" ] || [ "${local_host}" = "{{hostname}}" ]; then
    bash -c "${verify_script}"
  else
    just _runtime_assert condition='[ -n "{{host_ip}}" ]' exit_msg="Remote format requires host_ip parameter."
    just _ssh_to_installer host_ip="{{host_ip}}" cmd="${verify_script}"
  fi

[private]
[doc("Internal routing logic for formatting explicitly defined data disks remotely or locally.")]
_format_data_disks_internal hostname host_ip:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🔍 Querying flake configuration for explicitly defined data disks..."
  nix_apply='x: builtins.concatStringsSep " " (builtins.concatMap (p: p.devices or []) x)'
  target_disks=$(just _query_nix_config hostname="{{hostname}}" \
    query="custom.system.zfs.storagePools" nix_apply_expr="${nix_apply}")
  just _verify_data_disk_topology hostname="{{hostname}}" host_ip="{{host_ip}}" \
    target_disks="${target_disks}"
  echo -e "\n⚠️  WARNING: You are about to DESTROY ALL DATA on the target disks listed above."
  read -r -p "Type 'WIPE' in all caps to confirm destruction: " confirm_wipe
  just _runtime_assert condition='[ "${confirm_wipe}" = "WIPE" ]' exit_msg="Data format aborted by user."
  for disk in ${target_disks}; do
    just _deep_wipe_disk disk="${disk}" host_ip="{{host_ip}}"
  done
  just _exec_zdata_zpool_create hostname="{{hostname}}" disks="${target_disks}" host_ip="{{host_ip}}"
  just _create_zfs_datasets hostname="{{hostname}}" host_ip="{{host_ip}}"

[private]
[doc("Create a new ZFS pool utilizing properties extracted dynamically from Nix configuration.")]
_exec_zdata_zpool_create hostname disks host_ip="":
  #!/usr/bin/env bash
  set -euo pipefail
  disk_array=({{disks}})
  pool_name="zdata_{{hostname}}"
  pool_mode=""
  if [ "${#disk_array[@]}" -ge 2 ]; then pool_mode="mirror"; fi
  compat_val=$(just _query_nix_config hostname="{{hostname}}" \
    query="disko.devices.zpool.zroot.options.compatibility")
  compat_flag="-o compatibility=${compat_val}"
  enc_flags=""
  if just _host_type_is hostname="{{hostname}}" expected_type="user-facing"; then
    zdata_encryption_keystring=$(just _get_sops_secret \
      secret_key="{{hostname}}_host_zfs_zdata_encryption_symkey" \
      file_path="secrets/{{hostname}}_host_secrets.yaml")
    echo -n "${zdata_encryption_keystring}" > "{{host_zdata_keystring_tempfile_path}}"
    enc_flags="-O encryption=aes-256-gcm -O keyformat=hex -O keylocation=file://{{host_zdata_keystring_tempfile_path}}"
    if [ -n "{{host_ip}}" ]; then
      just _scp_to_installer host_ip="{{host_ip}}" \
        local_path="{{host_zdata_keystring_tempfile_path}}" \
        remote_path="{{host_zdata_keystring_tempfile_path}}"
    fi
  fi
  create_cmd="zpool create -o ashift=12 ${compat_flag} -O compression=lz4 -O xattr=sa \
    -O acltype=posixacl -O atime=off ${enc_flags} -m none \"${pool_name}\" ${pool_mode} {{disks}} \
    && zpool export \"${pool_name}\""
  if [ -n "{{host_ip}}" ]; then
    just _ssh_to_installer host_ip="{{host_ip}}" cmd="${create_cmd}"
  else
    bash -c "${create_cmd}"
  fi
  echo "✅ Pool ${pool_name} created on data disk(s)"

# ==========================================
# DISKO & NIXOS INSTALLATION
# ==========================================

[private]
[doc("Invoke Disko to partition, format, and mount the OS drives.")]
_execute_disko_format_to_zroot_mnt hostname:
  @echo "⚙️  Formatting zroot OS disks via Disko..."
  @just _extract_zfs_zroot_passphrase_for_user_facing_host hostname="{{hostname}}"
  @{{nix_run}} "github:nix-community/disko" -- --mode format --flake ".#{{hostname}}"
  @echo "⏳ Waiting for USB enclosure block devices to settle..."
  @udevadm settle
  @echo "✅ Disko formatting complete."
  @echo "⚙️  Mounting zroot OS disks to /mnt via Disko..."
  @{{nix_run}} "github:nix-community/disko" -- --mode mount --flake ".#{{hostname}}"
  @echo "✅ Disko mounting complete."

[private]
[doc("Run the standard nixos-install command against the mounted /mnt environment.")]
_execute_nixos_install_to_zroot_mnt hostname:
  @echo "🚀 Installing NixOS to zroot OS disks at /mnt..."
  @nixos-install --flake ".#{{hostname}}" --no-root-passwd
  @echo "✅ NixOS installation complete."

[private]
[doc("The complete sequence of internal orchestration commands required to deploy a NixOS host.")]
_run_build_sequence hostname:
  @just _emplace_target_hostid hostname="{{hostname}}"
  @just _wipe_zroot_os_disks hostname="{{hostname}}"
  @just _execute_disko_format_to_zroot_mnt hostname="{{hostname}}"
  @just _inject_sops_host_keypair_to_zroot_mnt
  @just _inject_zdata_key_to_zroot_mnt_for_user_facing_host hostname="{{hostname}}"
  @just _execute_nixos_install_to_zroot_mnt hostname="{{hostname}}"
  @echo "✅ Build sequence for {{hostname}} complete."

