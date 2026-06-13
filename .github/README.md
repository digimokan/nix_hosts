# nix_hosts

NixOS configuration to set up various hosts.

[![Release](https://img.shields.io/github/release/digimokan/nix_hosts.svg?label=release)](https://github.com/digimokan/nix_hosts/releases/latest "Latest Release Notes")
[![License](https://img.shields.io/badge/license-MIT-blue.svg?label=license)](LICENSE.md "Project License")

## Table Of Contents

* [Purpose](#purpose)
* [List Of Hosts](#list-of-hosts)
* [Quick Start](#quick-start)
    * [Manage Secrets With SOPS](#manage-secrets-with-sops)
* [Deploy NixOS To A Host](#deploy-nixos-to-a-host)
    * [Boot Target Host From Installer Image](#boot-target-host-from-installer-image)
    * [Install NixOS To Target Host Over SSH](#install-nixos-to-target-host-over-ssh)
    * [Install NixOS To Target Host From Installer Image](#install-nixos-to-target-host-from-installer-image)
    * [Provision Target Host Data Disks](#provision-target-host-data-disks)
* [Deployed Usage](#deployed-usage)
    * [Manage ZFS Snapshots](#manage-zfs-snapshots)
    * [Add Missing Datasets To Storage Pool](#add-missing-datasets-to-storage-pool)
    * [Replace Old Or Failed Disk In Storage Pool](#replace-old-or-failed-disk-in-storage-pool)
    * [Add New Mirror To Storage Pool](#add-new-mirror-to-storage-pool)
    * [Replace Entire Storage Pool](#replace-entire-storage-pool)
* [Source Code Layout](#source-code-layout)
* [Contributing](#contributing)

## Purpose

* Monorepo for NixOS configuration for various hosts.
* Hosts may be on separate LANs.
* Hosts are all configured with ZFS-on-root (single-disk, or mirror).

## List Of Hosts

* [`nas`](./docs/nas.md): main NAS on `GLAN`.
* [`tm1`](./docs/tm1.md): test user machine on `GLAN`.

## Manage Secrets With SOPS

See documentation in [`.sops.yaml`](../.sops.yaml).

## Deploy NixOS To A Host

### Boot Target Host From Installer Image

1. Download
   [NixOS Linux Distribution, Minimal ISO Image, 64-bit Intel/AMD](https://nixos.org/download/#download-nix).

2. Write the installer image to a
   [bootable USB stick](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux).

3. Insert the USB stick into the target host.

4. Power up the target host and
   [boot from the installer image](https://nixos.org/manual/nixos/stable/#sec-installation-booting).

   * Note: Per NixOS manual, try UEFI boot option first.
   * Note: Per NixOS manual, in the boot menu, select the default boot option.

### Install NixOS To Target Host Over SSH

1. On the target host, at the minimal installer prompt, set the password for the
   `nixos` user, for SSH:

   ```shell
   $ passwd
   ```

2. On the orchestration host, ensure the following packages are installed:

   * `age`
   * `sops`
   * `jq`
   * `just`

3. On the orchestration host, deploy NixOS to the target machine over SSH:

   Deploy, using default SOPS master secret keyfile at
   `/home/user2/.config/sops/age/keys.txt`:

   ```shell
   $ just deploy hostname=nas installer_host_ip=192.168.1.50
   ```

   Deploy, using SOPS master secret keyfile obtained from a command:

   ```shell
   $ just deploy hostname=nas get_master_secret_cmd="cat /tmp/mysecret.txt" installer_host_ip=192.168.1.50
   ```

### Install NixOS To Target Host From Installer Image

1. On the target host, clone this repo, change directory, and install dependencies:

   ```shell
   $ git clone https://github.com/digimokan/nix_hosts.git
   $ cd nix_hosts
   $ nix-shell -p just sops
   ```

2. On the target host, deploy NixOS:

   Deploy, using default SOPS master secret keyfile at
   `/home/nixos/.config/sops/age/keys.txt`:

   ```shell
   $ just deploy hostname=nas
   ```

   Deploy, using SOPS master secret keyfile obtained from a command:

   ```shell
   $ just deploy hostname=nas get_master_secret_cmd="cat /tmp/mysecret.txt"
   ```

### Provision Target Host Data Disks

Hosts that have a `data-disk-config.nix` file have dedicated data disk(s)
containing a `zdata_<hostname>` zpool.

User-facing hosts (hosts with `infrastructure.hostType=user-facing`) use SOPS
to encrypt the data disk(s) with a keystring. The keystring is then stored on
the `zroot` OS disk(s), and finally the `zroot` OS disks are protected with
a passphrase that must be entered on boot. The `justfile` performs all these
setup actions when `deploy` is executed.

On initial setup (with empty data disk(s)), provision the data disk(s) with
the `zdata` zpool and datasets:

   ```shell
   $ just format-data-disks hostname=nas get_master_secret_cmd="cat /tmp/mysecret.txt" installer_host_ip=192.168.1.50
   ```

## Deployed Usage

### Manage ZFS Snapshots

* Snapshots are enabled in the host's `default.nix`.
* See [`sanoid.nix`](../modules/apps/sanoid.nix) for guidance on working with
  snapshots.

### Add Missing Datasets To Storage Pool

1. Add the new datasets to the host's `zfs.storagePools` `datasets` field.

2. On the deployed host, create the missing datasets:

  ```shell
  $ just create-datasets hostname=nas get_master_secret_cmd="cat /tmp/mysecret.txt"
  ```

### Replace Old Or Failed Disk In Storage Pool

1. Note the old or failed disk, with `zpool status`:

  ```shell
  mirror-x                DEGRADED  0  0  0
  wwn-abc777def777ghi7  ONLINE    0  0  0
  14829562948105726384  UNAVAIL   0  0  0  was /dev/disk/by-id/wwn-stu666vwx666yzz6
  ```

2. Remove the failed disk from the NAS. Put a new disk in the NAS in its place.

3. Note the `/dev/disk/by-id` of the new disk, e.g. `wwn-jkl888mno888pqr8`.

4. Activate the new disk:

  ```shell
  $ zpool replace zdata_nas 14829562948105726384 /dev/disk/by-id/wwn-jkl888mno888pqr8
  ```

5. Once the `replace` operation is complete, if the vdev can now be expanded to
   make use of larger disks in the vdev, tell zfs to expand the vdev's size:

  ```shell
  $ zpool online -e zdata_nas /dev/disk/by-id/wwn-jkl888mno888pqr8
  ```

### Add New Mirror To Storage Pool

Add two new disks to existing storage pool `zdata_nas`, as a mirror vdev:

  ```shell
  $ zpool add zdata_nas mirror \
      /dev/disk/by-id/<DISK3-BY-ID> \
      /dev/disk/by-id/<DISK4-BY-ID>
  ```

### Replace Entire Storage Pool

Perform these steps to start over with new data disks:

1. Physically replace all data disks.

2. Note the `/dev/disk/by-id` of the new disk(s), e.g. `wwn-jkl888mno888pqr8`.

    * For a large pool with many mirrors, just note the first two disks that
      comprise the first mirror. Use these disks in the `data-disk-config.nix`.

3. Specify the new disk IDs in the host's `data-disk-config.nix`.

4. On the deployed host, provision the data disk(s) with the `zdata` zpool and
   datasets:

   ```shell
   $ just format-data-disks hostname=nas get_master_secret_cmd="cat /tmp/mysecret.txt" installer_host_ip=192.168.1.50
   ```

5. If more than two disks were emplaced in step 1, add each remaining pair
of disks as a [new mirror](#add-new-mirror-to-storage-pool).

## Source Code Layout

```
├─┬ nix_hosts/
│ │
│ ├─┬ hosts/
│ │ │
│ │ └─┬ xxx/                # config for a specific host
│ │   │
│ │   ├── default.nix           # configuration settings for the host
│ │   ├── os-disk-config.nix    # disk IDs for host's OS (zroot) disks
│ │   └── data-disk-config.nix  # disk IDs for host's data disks, if applicable
│ │
│ ├─┬ modules/
│ │ │
│ │ └─┬── apps/             # settings for installable apps and services
│ │   ├── infrastructure/   # settings shared/used by multiple hosts/modules.
│ │   ├── system/           # settings for linux "built-ins"
│ │   └── users/            # settings for specific users
│ │
│ ├── secrets/              # secrets files encrypted by SOPS
│ │
│ ├── .sops.yaml            # setup for SOPS secret management
│ │
│ ├── flake.lock            # locks the upstream repo states of flake.nix inputs
│ │
│ ├── flake.nix             # registry of hosts, repo sources, shared options
│ │
│ ├── justfile              # deploy NixOS to host, configure host, etc
│ │
```

## Contributing

* Feel free to report a bug or propose a feature by opening a new
  [Issue](https://github.com/digimokan/nix_hosts/issues).
* Follow the project's [Contributing](CONTRIBUTING.md) guidelines.
* Respect the project's [Code Of Conduct](CODE_OF_CONDUCT.md).

