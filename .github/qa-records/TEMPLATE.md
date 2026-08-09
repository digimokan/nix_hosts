# QA Testing Matrix: vX.X

## Phase 1: Bare Metal Provisioning (`deploy`)
- [ ] **Remote Deploy, Default Master Key:** `just deploy nas 192.168.1.50`
  * Deploys over SSH, usezs default `~/.config/sops/age/keys.txt` master key on orchestration machine.
- [ ] **Local Deploy, Get Master Key:** `sudo just deploy tm1 "" "cat /tmp/test_key.txt"`
  * Deploys directly on Live ISO, uses empty string `""` to skip IP argument, SOPS key extraction with a custom command.

## Phase 2: SOPS Secrets
- [ ] **Edit Secret:** `just edit-secret secrets/vbc_zone_secrets.yaml`
  * Edits secrets file with SOPS, rekeys other secrets files as needed.
- [ ] **Global Rekey:** `just rekey-secrets`
  * Rekeys all secrets files as needed, after creating a _new_ secrets file.

## Phase 3: Data Disk Management On Deployed Host
- [ ] **Format Data Disks:** `sudo just format-data-disks nas`
  * Creates `zdata` zpool and datasets on data disks.
- [ ] **Create Datasets:** `sudo just update-datasets nas`
  * Creates missing `zdata` datasets, changes dataset properties on existing `zdata` datasets.

## Phase 4: NixOS Operations On Deployed Host
- [ ] **Local/Remote Syntax Validation:** `just check`
  * Validates flake and configuration.
- [ ] **Remote Rebuild:** `just rebuild nas`
  * Rebuilds target host from orchestration machine.
- [ ] **Local Rebuild:** `sudo just rebuild nas`
  * Rebuilds target host locally.
- [ ] **Local/Remote Rebuild-Test:** `just rebuild-test nas`
  * Switches into rebuilt host, without emplacing generation (can reboot into old build).
- [ ] **Local/Remote List-Generations:** `just list-generations nas`
  * List all generations for target host.
- [ ] **Local/Remote Flake Update:** `just update`
  * Updates flake inputs.

