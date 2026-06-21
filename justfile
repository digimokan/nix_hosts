# vim: set filetype=just:

# ==========================================
# JUST CONFIGURATION
# ==========================================

set shell := ["bash", "-euo", "pipefail", "-c"]

# ==========================================
# GLOBAL VARIABLES
# ==========================================

repo_url := "https://github.com/digimokan/nix_hosts.git"

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
host_keypair_native_dir := "/var/lib/sops-nix"
host_keypair_native_path := host_keypair_native_dir / "host_keypair.age"
host_zdata_keystring_tempfile_path := "/tmp/nix_hosts_zfs_zdata_keystring"

ssh_opts := "-o ControlMaster=auto -o ControlPath=/tmp/deploy_ssh_%h_%p_%r -o ControlPersist=10m"

# ==========================================
# PUBLIC RECIPES
# ==========================================

[default]
[doc("Show this help menu.\n  Ex: just")]
help:
  @just --list --unsorted

[doc("Check the flake for evaluation errors.\n  Ex: just check")]
check:
  @echo "🚧 Initiating flake config check..."
  @nix flake check
  @echo "{{BOLD}}{{GREEN}}✅ Flake check completed successfully.{{NORMAL}}"

[doc("Update all flake inputs to their latest versions based on flake.nix.\n  Ex: just update nas")]
update:
  @echo "📥 Initiating update of all flake.nix inputs..."
  @nix flake update
  @echo "{{BOLD}}{{GREEN}}✅ Flake inputs updated successfully. Commit any changes to git.{{NORMAL}}"

[doc("Rebuild and switch NixOS configuration locally or remotely.\n  Ex: just rebuild nas")]
rebuild hostname: _require_root
  @just _exec_nixos_rebuild_cmd "{{hostname}}" "switch"

[doc("Rebuild and test NixOS configuration without making it the boot default.\n  Ex: just rebuild-test nas")]
rebuild-test hostname: _require_root
  @just _exec_nixos_rebuild_cmd "{{hostname}}" "test"

[doc("List the system generations for a given host.\n  Ex: just list-generations nas")]
list-generations hostname: _require_root
  @just _exec_nixos_rebuild_cmd "{{hostname}}" "list-generations"

[doc("Deploy NixOS to local or remote host running NixOS installer.\n  Ex: just deploy nas\n  Ex: just deploy nas 'cat my_master_secret.txt'\n  Ex: just deploy nas 192.168.1.50")]
deploy hostname installer_host_ip="" get_master_secret_cmd="": _require_root
  @just _deploy_internal \
    "{{hostname}}" "{{installer_host_ip}}" "{{get_master_secret_cmd}}" \
    || { just _cleanup_temp_files; exit 1; }
  @just _cleanup_temp_files

[doc("Wipe and format the hosts zdata pool on its data disks.\n  Ex: just format-data-disks tm1")]
format-data-disks hostname: _require_root
  @just _format_data_disks_internal "{{hostname}}" || { just _cleanup_temp_files; exit 1; }
  @just _cleanup_temp_files

[doc("Create all missing ZFS datasets on the host's zdata pool.\n  Ex: just create-datasets tm1")]
create-datasets hostname: _require_root
  @just _create_datasets_internal "{{hostname}}"  || { just _cleanup_temp_files; exit 1; }
  @just _cleanup_temp_files

[doc("Edit a SOPS file and automatically rekey all secrets.\n  Ex: just edit-secret secrets/admin.yaml")]
edit-secret target_file:
  #!/usr/bin/env bash
  set -euo pipefail
  just _runtime_assert condition='[ -f "{{target_file}}" ]' exit_msg="Target file not found."
  echo "📝 Opening {{target_file}} via SOPS..."
  {{sops_cmd}} "{{target_file}}"
  echo "{{GREEN}}✔ Secret file editing complete.{{NORMAL}}"
  just _rekey_all_sops_secrets_files
  echo "{{BOLD}}{{GREEN}}✅ Secrets editing and rekeying complete. Commit any changes to Git.{{NORMAL}}"

# ==========================================
# PRIVATE RECIPES (Internal Logic)
# ==========================================

[private]
[doc("Ensure the user is running as root.")]
_require_root:
  @just _runtime_assert '[ "$(id -u)" -eq 0 ]' "This operation requires sudo."

[private]
[doc("Evaluate a bash conditional and exit loudly with a custom message if it fails.")]
_runtime_assert condition exit_msg:
  @if ! {{condition}}; then echo "Error: {{exit_msg}}" >&2; exit 1; fi

[private]
[doc("Execute a command silently, ignoring any errors or output.")]
_exec_silent_ignore_errs cmd:
  @bash -c "{{cmd}}" >/dev/null 2>&1 || true

[private]
[doc("Install required dependencies on the remote installer host.")]
_install_required_deps installer_host_ip:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -n "{{installer_host_ip}}" ]; then
  echo "🔩 Installing required dependencies on remote installer ISO..."
    just _ssh_cmd "nixos@{{installer_host_ip}}" "nix-env --install --attr nixos.just"
    echo "{{GREEN}}✔ Dependencies installed.{{NORMAL}}"
  fi

[private]
[doc("Purge sensitive files. Used safely via logical OR short-circuits in public recipes.")]
_cleanup_temp_files:
  @just _exec_silent_ignore_errs "rm -f {{host_keypair_tempfile_path}}"
  @just _exec_silent_ignore_errs "rm -f {{host_zdata_keystring_tempfile_path}}"
  @just _exec_silent_ignore_errs "rm -f /tmp/nix_hosts_*"
  @just _exec_silent_ignore_errs "rm -f /tmp/deploy_ssh_*"

[private]
[doc("Query Nix config. Asserts value exists.")]
_query_nix_config hostname query nix_apply_expr="":
  #!/usr/bin/env bash
  set -euo pipefail
  expr='{{nix_apply_expr}}'
  result=$(eval "{{nix_eval}} --raw \".#nixosConfigurations.{{hostname}}.config.{{query}}\" ${expr:+--apply '${expr}'}")
  just _runtime_assert "[ -n \"${result}\" ]" "Nix query {{query}} returned empty/null."
  echo -n "${result}"

[private]
[doc("Extract a secret from SOPS. Asserts file exists and secret is not empty.")]
_get_sops_secret secret_to_get secrets_file_path master_secret_keystring="":
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -n "{{master_secret_keystring}}" ]; then
    export SOPS_AGE_KEY="{{master_secret_keystring}}"
  elif [ -f "{{host_keypair_tempfile_path}}" ]; then
    export SOPS_AGE_KEY_FILE="{{host_keypair_tempfile_path}}"
  elif [ -f "{{host_keypair_native_path}}" ]; then
    export SOPS_AGE_KEY_FILE="{{host_keypair_native_path}}"
  else
    just _runtime_assert false "Error: Could not locate a valid SOPS age key for decryption."
  fi
  just _runtime_assert '[ -f "{{secrets_file_path}}" ]' "Could not find {{secrets_file_path}}"
  secret_val=$({{sops_cmd}} -d --extract "[\"{{secret_to_get}}\"]" \
    "{{secrets_file_path}}")
  just _runtime_assert \
    "[ -n \"${secret_val}\" ]" \
    "Could not find {{secret_to_get}} in {{secrets_file_path}}"
  echo -n "${secret_val}"

[private]
[doc("Iterate through all SOPS YAML files and rekey them.")]
_rekey_all_sops_secrets_files:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🏭 Rekeying all YAML files in secrets/ directory..."
  for secret_file in secrets/*.yaml; do
    if [ -f "${secret_file}" ]; then
      echo "   - Updating keys for ${secret_file}..."
      {{sops_cmd}} updatekeys -y "${secret_file}"
    fi
  done
  echo "{{GREEN}}✔ Secrets rekeying operations complete.{{NORMAL}}"

[private]
[doc("Silent boolean check if executing locally (either on installer or post-deployment host).")]
_is_execution_local hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  local_host="$(hostname)"
  if [ "${local_host}" = "nixos" ] || [ "${local_host}" = "{{hostname}}" ]; then
    echo "true"
  else
    echo "false"
  fi

[private]
[doc("Get extra SSH options to use if connecting to the ephemeral NixOS installer.")]
_ssh_get_installer_extra_opts user_at_host:
  #!/usr/bin/env bash
  set -euo pipefail
  if [[ "{{user_at_host}}" == nixos@* ]]; then
    echo "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null";
  fi

[private]
[doc("Base SSH command to run.")]
_ssh_cmd user_at_host cmd:
  #!/usr/bin/env bash
  set -euo pipefail
  extra_opts="$(just _ssh_get_installer_extra_opts "{{user_at_host}}")"
  ssh {{ssh_opts}} ${extra_opts} "{{user_at_host}}" {{quote(cmd)}}

[private]
[doc("Base SCP command to run.")]
_scp_cmd user_at_host local_path remote_path:
  #!/usr/bin/env bash
  set -euo pipefail
  extra_opts="$(just _ssh_get_installer_extra_opts "{{user_at_host}}")"
  scp {{ssh_opts}} ${extra_opts} "{{local_path}}" "{{user_at_host}}:{{remote_path}}"

[private]
[doc("Execute a command locally, or over SSH via installer IP or Tailscale.")]
_exec_cmd_local_or_ssh hostname installer_host_ip cmd:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -n "{{installer_host_ip}}" ]; then
    just _ssh_cmd "nixos@{{installer_host_ip}}" {{quote(cmd)}}
  elif $(just _is_execution_local "{{hostname}}"); then
    bash -c {{quote(cmd)}}
  else
    just _ssh_cmd "root@{{hostname}}" {{quote(cmd)}}
  fi

[private]
[doc("Transfer a file locally, or over SCP via installer IP or Tailscale.")]
_scp_cmd_local_or_ssh hostname installer_host_ip local_path remote_path:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -n "{{installer_host_ip}}" ]; then
    just _scp_cmd "nixos@{{installer_host_ip}}" "{{local_path}}" "{{remote_path}}"
  elif $(just _is_execution_local "{{hostname}}"); then
    if [ "{{local_path}}" != "{{remote_path}}" ]; then
      cp "{{local_path}}" "{{remote_path}}"
    fi
  else
    just _scp_cmd "root@{{hostname}}" "{{local_path}}" "{{remote_path}}"
  fi

[private]
[doc("Silent boolean check to determine if running on the installer host.")]
_is_running_on_installer_host hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  local_host="$(hostname)"
  if [ "${local_host}" = "nixos" ] || [ "${local_host}" = "{{hostname}}" ]; then exit 0; else exit 1; fi

[private]
[doc("Silent boolean check for host type.")]
_host_type_is hostname expected_type:
  #!/usr/bin/env bash
  set -euo pipefail
  host_type=$(just _query_nix_config "{{hostname}}" "custom.infrastructure.hostType")
  if [ "${host_type}" = "{{expected_type}}" ]; then
    echo "true"
  else
    echo "false"
  fi

# ==========================================
# ORCHESTRATION ROUTING & DEPLOYMENT
# ==========================================

[private]
[doc("Select and run the appropriate install: local or remote.")]
_deploy_internal hostname installer_host_ip get_master_secret_cmd:
  #!/usr/bin/env bash
  set -euo pipefail
  master_key=$(just _get_sops_master_secret_keystring "{{get_master_secret_cmd}}")
  just _extract_host_age_keypair_to_tmpfile "{{hostname}}" "${master_key}"
  if $(just _is_execution_local "{{hostname}}"); then
    just _deploy_local "{{hostname}}"
  else
    just _runtime_assert '[ -n "{{installer_host_ip}}" ]' "Remote deploy requires installer_host_ip parameter."
    just _deploy_remote "{{hostname}}" "{{installer_host_ip}}"
  fi

[private]
[doc("Deploy NixOS on local host that is running the NixOS installer ISO.")]
_deploy_local hostname:
  @echo "🚀 Initiating local deployment for {{hostname}}..."
  @just _run_build_sequence "{{hostname}}"
  @echo "{{BOLD}}{{GREEN}}✅ Local deployment finished.{{NORMAL}}"
  @echo "{{BOLD}}{{GREEN}}✅ Reboot into new OS.{{NORMAL}}"
  @echo "{{BOLD}}{{GREEN}}✅ Then Run \"just format-data-disks\", as required.{{NORMAL}}"

[private]
[doc("Deploy NixOS to remote host (via SSH) that is running the NixOS installer ISO.")]
_deploy_remote hostname installer_host_ip:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🚀 Initiating remote deployment to host {{hostname}} at {{installer_host_ip}}..."
  just _install_required_deps "{{installer_host_ip}}"
  echo "🗑️ Removing any existing repository on remote host..."
  just _exec_cmd_local_or_ssh \
    "{{hostname}}" \
    "{{installer_host_ip}}" \
    "rm -rf /tmp/nix_hosts {{host_keypair_tempfile_path}}"
  echo "{{GREEN}}✔ Repository removal complete.{{NORMAL}}"
  echo "📦 Cloning repository on remote host..."
  just _exec_cmd_local_or_ssh \
    "{{hostname}}" \
    "{{installer_host_ip}}" \
    "git clone --single-branch --depth=1 '{{repo_url}}' /tmp/nix_hosts"
  echo "{{GREEN}}✔ Repository clone complete.{{NORMAL}}"
  echo "📲 Transferring SOPS host keypair to remote host temporary storage..."
  just _scp_cmd_local_or_ssh \
    "{{hostname}}" \
    "{{installer_host_ip}}" \
    "{{host_keypair_tempfile_path}}" \
    "{{host_keypair_tempfile_path}}"
  echo "{{GREEN}}✔ Transfer of SOPS host keypair complete.{{NORMAL}}"
  echo "⚙️ Executing build sequence on remote host over SSH..."
  just _exec_cmd_local_or_ssh \
    "{{hostname}}" \
    "{{installer_host_ip}}" \
    "cd /tmp/nix_hosts && sudo /home/nixos/.nix-profile/bin/just _run_build_sequence \"{{hostname}}\""
  echo "{{BOLD}}{{GREEN}}✅ Remote deployment finished.{{NORMAL}}"
  echo "{{BOLD}}{{GREEN}}✅ Reboot into the target host's new OS.{{NORMAL}}"
  echo "{{BOLD}}{{GREEN}}✅ Then run \"just format-data-disks\" on target host, as required.{{NORMAL}}"

[private]
[doc("Execute a nixos-rebuild action locally or remotely via Tailscale.")]
_exec_nixos_rebuild_cmd hostname action:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🏗️ Initiating NixOS rebuild ({{action}}) for {{hostname}}..."
  if [ "$(hostname)" = "{{hostname}}" ]; then
    nixos-rebuild {{action}} --flake ".#{{hostname}}"
  else
    nixos-rebuild {{action}} --flake ".#{{hostname}}" --target-host "root@{{hostname}}"
  fi
  echo "{{BOLD}}{{GREEN}}✅ Rebuild action complete.{{NORMAL}}"

# ==========================================
# SECRETS EXTRACTION & INJECTION
# ==========================================

[private]
[doc("Retrieve master secret from command, or default file.")]
_get_sops_master_secret_keystring get_master_secret_cmd:
  #!/usr/bin/env bash
  set -euo pipefail
  if [ -n "{{get_master_secret_cmd}}" ]; then
    echo "🔏 get_master_secret_cmd option selected, invoking cmd arg to get Master Key..." >&2
    master_secret_keystring=$(eval "{{get_master_secret_cmd}}")
  else
    actual_home_dir=$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)
    keyfile="${actual_home_dir}/.config/sops/age/keys.txt"
    echo "🗝️ No master secret option selected, using default keyfile at ${keyfile}..." >&2
    just _runtime_assert "[ -f \"${keyfile}\" ]" "Master keyfile not found at ${keyfile}"
    master_secret_keystring=$(grep -m 1 "^AGE-SECRET-KEY-" "${keyfile}" || true)
  fi
  just _runtime_assert "[ \"${#master_secret_keystring}\" -eq 74 ]" "Invalid key length."
  echo "{{GREEN}}✔ Master-Secret-Keystring successfully obtained (storing in RAM only).{{NORMAL}}" >&2
  echo -n "${master_secret_keystring}"

[private]
[doc("Extract the target host Age keypair to a /tmp file, from the master SOPS vault.")]
_extract_host_age_keypair_to_tmpfile hostname master_key:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🔐 Using SOPS master keystring to extract target Age keypair for host '{{hostname}}'..." >&2
  key_value=$(just _get_sops_secret "age_keypair_host_{{hostname}}" "secrets/master_secrets.yaml" "{{master_key}}")
  echo "${key_value}" > "{{host_keypair_tempfile_path}}"
  chmod 600 "{{host_keypair_tempfile_path}}"
  echo "{{GREEN}}✔ Host Age keypair successfully extracted to {{host_keypair_tempfile_path}}.{{NORMAL}}" >&2

[private]
[doc("Extract plaintext ZFS passphrase to feed to Disko for user-facing hosts.")]
_extract_zfs_zroot_passphrase_for_user_facing_host hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! $(just _host_type_is "{{hostname}}" "user-facing"); then exit 0; fi
  echo "📇 Querying Nix config for location of zroot passphrase tempfile path on target host..." >&2
  passphrase_tempfile_path=$(just _query_nix_config \
    "{{hostname}}" \
    "custom.system.zfs.zrootPoolSchema.rootFsEncryptionTempfilePath")
  echo "{{GREEN}}✔ Query complete: zroot passphrase tempfile path is ${passphrase_tempfile_path}.{{NORMAL}}" >&2
  echo "🔑 Using SOPS host keypair to extract host plaintext ZFS zroot passphrase to '${passphrase_tempfile_path}'..." >&2
  pass_value=$(just _get_sops_secret \
    "{{hostname}}_host_zfs_zroot_encryption_passphrase" \
    "secrets/{{hostname}}_host_secrets.yaml")
  echo -n "${pass_value}" > "${passphrase_tempfile_path}"
  echo "{{GREEN}}✔ Host ZFS zroot passphrase successfully extracted to ${passphrase_tempfile_path}.{{NORMAL}}" >&2

[private]
[doc("Inject the SOPS host keypair into the newly mounted root filesystem.")]
_inject_sops_host_keypair_to_zroot_mnt:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "💉 Injecting SOPS host keypair into the newly formatted host zroot at /mnt..."
  mkdir -p "/mnt{{host_keypair_native_dir}}"
  cp "{{host_keypair_tempfile_path}}" "/mnt{{host_keypair_native_path}}"
  chmod 400 "/mnt{{host_keypair_native_path}}"
  echo "{{GREEN}}✔ SOPS keypair injected successfully.{{NORMAL}}"

[private]
[doc("Inject ZFS zdata encryption keystring to enable auto-unlocking on boot for user-facing hosts.")]
_inject_zdata_key_to_zroot_mnt_for_user_facing_host hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if ! $(just _host_type_is "{{hostname}}" "user-facing"); then exit 0; fi
  echo "🧩 Emplacing ZFS zdata encryption keystring to target host's zroot /mnt/persist/zfs-keys..."
  zdata_encryption_keystring=$(just _get_sops_secret \
    "{{hostname}}_host_zfs_zdata_encryption_symkey" \
    "secrets/{{hostname}}_host_secrets.yaml")
  mkdir -p /mnt/persist/zfs-keys
  echo -n "${zdata_encryption_keystring}" > "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"
  chmod 400 "/mnt/persist/zfs-keys/zdata_{{hostname}}.key"
  echo "{{GREEN}}✔ Zdata encryption keystring emplaced successfully.{{NORMAL}}"

[private]
[doc("Extract and emplace the networking.hostId to prevent ZFS import mismatch issues.")]
_emplace_target_hostid hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "📜 Querying Nix config for target host ZFS hostId to NixOS installer..."
  target_hostid=$(just _query_nix_config "{{hostname}}" "networking.hostId")
  echo "{{GREEN}}✔ Query complete: target host hostId is ${target_hostid}.{{NORMAL}}"
  echo "🧬 Setting target host hostId on NixOS installer..."
  rm -f /etc/hostid
  zgenhostid "${target_hostid}"
  echo "{{GREEN}}✔ Installer hostId set to ${target_hostid}.{{NORMAL}}"

# ==========================================
# DISK WIPING & ZFS MANAGEMENT
# ==========================================

[private]
[doc("Deeply wipe all partitions and labels from a single block device.")]
_deep_wipe_disk disk:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "☢️  Nuking {{disk}}..."
  silent_exec() { "$@" >/dev/null 2>&1 || true; }
  for part in $(lsblk -plno NAME "{{disk}}" 2>/dev/null | sort -r); do
    if [ "$part" != "{{disk}}" ]; then
      echo "   - Erasing signatures on $part..."
      silent_exec mdadm --zero-superblock --force "$part"
      silent_exec zpool labelclear -f "$part"
      silent_exec wipefs -a -f "$part"
    fi
  done
  silent_exec blkdiscard -f "{{disk}}"
  silent_exec mdadm --zero-superblock --force "{{disk}}"
  silent_exec zpool labelclear -f "{{disk}}"
  silent_exec wipefs -a -f "{{disk}}"
  silent_exec sgdisk --zap-all "{{disk}}"
  silent_exec partprobe "{{disk}}"
  sleep 2
  echo "{{GREEN}}✔ Nuke of disk {{disk}} complete.{{NORMAL}}"

[private]
[doc("Validate and wipe all OS disks associated with the target host in the Disko config.")]
_wipe_zroot_os_disks hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🪄 Querying Nix config for required OS zroot disks..."
  nix_apply='x: builtins.concatStringsSep " " (builtins.map (d: d.device) (builtins.attrValues x))'
  target_disks=$(just _query_nix_config "{{hostname}}" "disko.devices.disk" "${nix_apply}")
  echo "{{GREEN}}✔ Query complete: zroot OS disks obtained successfully.{{NORMAL}}"
  echo "🧹 Tearing down non-disk-specific active OS mounts and volumes..."
  just _exec_silent_ignore_errs "swapoff -a"
  just _exec_silent_ignore_errs "umount -R /mnt"
  just _exec_silent_ignore_errs "zfs unmount -a"
  just _exec_silent_ignore_errs "zpool export -f -a"
  just _exec_silent_ignore_errs "dmsetup remove_all -f"
  just _exec_silent_ignore_errs "vgchange -an"
  just _exec_silent_ignore_errs "mdadm --stop --scan"
  echo "{{GREEN}}✔ Disk mounts and volumes tear-down complete.{{NORMAL}}"
  for disk in ${target_disks}; do
    just _deep_wipe_disk "${disk}"
  done

[private]
[doc("Query Nix config and parse JSON to extract ZFS dataset paths and properties.")]
_query_nix_config_for_zdata_datasets hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "📐 Querying Nix config for required ZFS datasets on zdata disks..." >&2
  json_data=$({{nix_eval}} --json \
    ".#nixosConfigurations.{{hostname}}.config.custom.system.zfs.storagePoolSchemas")
  echo "${json_data}" | {{jq_cmd}} -r '
    .[] as $pool |
    def walk_datasets(parent_path):
      .[] |
      (parent_path + "/" + .name) as $path |
      (
        (if .mountPoint != null then "-o mountpoint=legacy " else "" end) +
        "-o compression=" + .compression + " " +
        "-o recordsize=" + .recordsize + " " +
        "-o exec=" + .exec + " " +
        "-o setuid=" + .setuid
      ) as $opts |
      "\($path)|\($opts)",
      (if (.children | length) > 0 then (.children | walk_datasets($path)) else empty end);
    $pool.datasets | walk_datasets($pool.poolName)
  '
  echo "{{GREEN}}✔ Query complete: zdata dataset paths and properties obtained successfully.{{NORMAL}}" >&2

[private]
[doc("Query the Nix config and create required ZFS datasets on zdata disks.")]
_create_zdata_datasets hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "🗄️ Initiating creation of datasets on zdata data disks..."
  dataset_lines="$(just _query_nix_config_for_zdata_datasets "{{hostname}}")"
  while IFS='|' read -r ds_path ds_opts; do
    echo "🎛️ Verifying dataset ${ds_path} exists, or creating it as required."
    if zfs list "${ds_path}" >/dev/null 2>&1; then
      echo "{{GREEN}}Dataset ${ds_path} already exists.{{NORMAL}}"
    else
      zfs create ${ds_opts} "${ds_path}"
      echo "{{GREEN}}Created: ${ds_path}{{NORMAL}}"
    fi
  done <<< "${dataset_lines}"
  echo "{{BOLD}}{{GREEN}}✅ Creation of datasets on zdata data disks complete.{{NORMAL}}"

[private]
[doc("Create zdata datasets, with legacy mountpoints.")]
_create_datasets_internal hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  just _create_zdata_datasets "{{hostname}}"

[private]
[doc("Verify disk topology visually and prompt for confirmation before formatting.")]
_confirm_data_disks_format target_disks:
  #!/usr/bin/env bash
  set -euo pipefail
  echo -e "\nℹ️ TARGET TOPOLOGY VERIFICATION:"
  echo "--- All Disks on System ---"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT
  echo -e "\n--- Target Disks for zdata Pool ---"
  for d in {{target_disks}}; do
    ls -l /dev/disk/by-id/ | grep "$(basename "$d")" || true
  done
  echo -e "\n⚠️ WARNING: You are about to DESTROY ALL DATA on the target disks listed above."
  read -r -p "Type 'WIPE' in all caps to confirm destruction: " confirm_wipe
  just _runtime_assert "[ \"${confirm_wipe}\" = \"WIPE\" ]" "Data format aborted by user."

[private]
[doc("Format explicitly defined data disks locally.")]
_format_data_disks_internal hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  echo "💾 Initiating wipe and format of zdata data disks..."
  echo "🕵️ Querying flake configuration for explicitly defined zdata data disks..."
  nix_apply='x: builtins.concatStringsSep " " (builtins.concatMap (p: p.disks or []) x)'
  target_disks=$(just _query_nix_config "{{hostname}}" "custom.system.zfs.storagePoolSchemas" "${nix_apply}")
  echo "{{GREEN}}✔ Query complete: zdata data disk paths obtained successfully.{{NORMAL}}"
  just _confirm_data_disks_format "${target_disks}"
  for disk in ${target_disks}; do
    just _deep_wipe_disk "${disk}"
  done
  just _create_zdata_zpool "{{hostname}}" "${target_disks}"
  echo "{{BOLD}}{{GREEN}}✅ Wipe and format of zdata data disks complete.{{NORMAL}}"
  just _create_zdata_datasets "{{hostname}}"

[private]
[doc("Determine the ZFS pool mode (e.g. 'mirror') based on disk count.")]
_get_zpool_mode disks:
  #!/usr/bin/env bash
  set -euo pipefail
  disk_array=({{disks}})
  if [ "${#disk_array[@]}" -ge 2 ]; then echo "mirror"; fi

[private]
[doc("Retrieve user-facing host zdata zpool encryption flags.")]
_get_zpool_encryption_flags hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  if $(just _host_type_is "{{hostname}}" "user-facing"); then
    echo "🔗 Using SOPS host keypair to extract zdata encryption keystring for host '{{hostname}}'..." >&2
    zdata_encryption_keystring=$(just _get_sops_secret \
      "{{hostname}}_host_zfs_zdata_encryption_symkey" \
      "secrets/{{hostname}}_host_secrets.yaml")
    echo -n "${zdata_encryption_keystring}" > "{{host_zdata_keystring_tempfile_path}}"
    echo "-O encryption=aes-256-gcm -O keyformat=hex -O keylocation=file://{{host_zdata_keystring_tempfile_path}}"
    echo "{{GREEN}}✔ Zdata encryption keystring successfully extracted to local {{host_zdata_keystring_tempfile_path}}.{{NORMAL}}" >&2
  fi

[private]
[doc("Query Nix config to extract all zdata pool and root dataset properties.")]
_query_nix_config_for_zdata_pool_props hostname:
  #!/usr/bin/env bash
  set -euo pipefail
  json_data=$(just _query_nix_config "{{hostname}}" "custom.system.zfs.storagePoolSchemas")
  echo "${json_data}" | {{jq_cmd}} -r '
    .[] |
    "-o ashift=\(.poolAshift) -o compatibility=\(.poolCompatibility) \
    -O acltype=\(.rootFsAclType) -O xattr=\(.rootFsXattr) -O atime=\(.rootFsAtime) \
    -O compression=\(.rootFsCompression) -O recordsize=\(.rootFsRecordsize) \
    -O exec=\(.rootFsExec) -O setuid=\(.rootFsSetuid)"
  '

[private]
[doc("Create a new zdata data disks zpool.")]
_create_zdata_zpool hostname disks:
  #!/usr/bin/env bash
  set -euo pipefail
  pool_name="zdata_{{hostname}}"
  pool_mode="$(just _get_zpool_mode "{{disks}}")"
  pool_props="$(just _query_nix_config_for_zdata_pool_props "{{hostname}}")"
  pool_enc_flags="$(just _get_zpool_encryption_flags "{{hostname}}")"
  echo "🛠️ Creating zpool ${pool_name} on zdata disks..." >&2
  zpool create ${pool_props} ${pool_enc_flags} -m none \
               "${pool_name}" ${pool_mode} {{disks}}
  zpool export "${pool_name}"
  echo "{{GREEN}}✔ Pool ${pool_name} created on data disk(s){{NORMAL}}" >&2

# ==========================================
# DISKO & NIXOS INSTALLATION
# ==========================================

[private]
[doc("Invoke Disko to partition, format, and mount the OS drives.")]
_execute_disko_format_to_zroot_mnt hostname:
  @echo "⚙️  Formatting zroot OS disks via Disko..."
  @just _extract_zfs_zroot_passphrase_for_user_facing_host "{{hostname}}"
  @{{nix_run}} "github:nix-community/disko" -- --mode format --flake ".#{{hostname}}"
  @echo "{{GREEN}}✔ Disko formatting complete.{{NORMAL}}"
  @echo "⏳ Waiting for USB enclosure block devices to settle..."
  @udevadm settle
  @echo "{{GREEN}}✔ Block devices settling complete.{{NORMAL}}"
  @echo "⚙️ Mounting zroot OS disks to /mnt via Disko..."
  @{{nix_run}} "github:nix-community/disko" -- --mode mount --flake ".#{{hostname}}"
  @echo "{{GREEN}}✔ Disko mounting complete.{{NORMAL}}"

[private]
[doc("Run the standard nixos-install command against the mounted /mnt environment.")]
_execute_nixos_install_to_zroot_mnt hostname:
  @echo "🧱 Installing NixOS to zroot OS disks at /mnt..."
  @nixos-install --flake ".#{{hostname}}" --root "/mnt" --no-root-passwd
  @echo "{{GREEN}}✔ NixOS installation complete.{{NORMAL}}"

[private]
[doc("The complete sequence of internal orchestration commands required to deploy a NixOS host.")]
_run_build_sequence hostname:
  @just _emplace_target_hostid "{{hostname}}"
  @just _wipe_zroot_os_disks "{{hostname}}"
  @just _execute_disko_format_to_zroot_mnt "{{hostname}}"
  @just _inject_sops_host_keypair_to_zroot_mnt
  @just _inject_zdata_key_to_zroot_mnt_for_user_facing_host "{{hostname}}"
  @just _execute_nixos_install_to_zroot_mnt "{{hostname}}"

