# nix_hosts

NixOS configuration to set up various hosts.

[![Release](https://img.shields.io/github/release/digimokan/nix_hosts.svg?label=release)](https://github.com/digimokan/nix_hosts/releases/latest "Latest Release Notes")
[![License](https://img.shields.io/badge/license-MIT-blue.svg?label=license)](LICENSE.md "Project License")

## Table Of Contents

* [Purpose](#purpose)
* [List Of Hosts](#list-of-hosts)
* [Quick Start](#quick-start)
    * [Secret Management With SOPS](#secret-management-with-sops)
    * [Boot Target Host From Installer Image](#boot-target-host-from-installer-image)
    * [Install NixOS To Target Host Over SSH](#install-nixos-to-target-host-over-ssh)
    * [Install NixOS To Target Host From Installer Image](#install-nixos-to-target-host-from-installer-image)
* [Usage](#usage)
    * [ZFS Storage Pools](#zfs-storage-pools)
    * [ZFS Datasets](#zfs-datasets)
    * [ZFS Snapshots](#zfs-snapshots)
* [Source Code Layout](#source-code-layout)
* [Contributing](#contributing)

## Purpose

* Monorepo for NixOS configuration for various hosts.
* Hosts may be on separate LANs.
* Hosts are all configured with ZFS-on-root (single-disk, or mirror).

## List Of Hosts

* [`nas`](./docs/nas.md): main NAS on `GLAN`.
* [`tm1`](./docs/tm1.md): test user machine on `GLAN`.

## Quick Start

### Secret Management With SOPS

See documentation in [`.sops.yaml`](../.sops.yaml).

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

3. On the orchestration host, emplace the age master key.

   Option 1 is emplacing the age master key at `/home/user2/.config/sops/age/keys.txt`.

   Option 2 is setting the `SOPS_AGE_KEY` environment variable:

   ```shell
   $ export SOPS_AGE_KEY="
       # created: 2099-99-99T99:99:99Z
       # public key: age1XXXXXXXXX
       AGE-SECRET-KEY-XXXXXXXXX"
   ```

4. On the orchestration host, deploy NixOS to the target machine over SSH:

   ```shell
   $ ./run.sh --deploy-remote -T nas -R 192.168.1.50 -w
   ```

### Install NixOS To Target Host From Installer Image

1. On the target host, clone this repo, and change to the directory:

   ```shell
   $ git clone https://github.com/digimokan/nix_hosts.git
   $ cd nix_hosts
   ```

2. On the target host, emplace the age master key.

   Option 1 is emplacing the age master key at `/home/nixos/.config/sops/age/keys.txt`.

   Option 2 is setting the `SOPS_AGE_KEY` environment variable:

      ```shell
      $ export SOPS_AGE_KEY="
          # created: 2099-99-99T99:99:99Z
          # public key: age1XXXXXXXXX
          AGE-SECRET-KEY-XXXXXXXXX"
      ```

   Option 3 is invoking `run.sh` with the `-p` option, in the next step,
   which will prompt for entry of the age master secret key.

3. On the target host, deploy NixOS:

   ```shell
   $ sudo ./run.sh --deploy-local -T nas -w
   ```

## Usage

### ZFS Storage Pools

Some hosts have one or more additional storage pools, in addition to the root
`zroot` pool. Storage pools and their vdevs and datasets are managed manually.

#### Create Pool

Create a new storage pool `zdata`, mounted on `/data`, from two mirrored disks:

   ```shell
   $ zpool create -o ashift=12 -m /data zdata mirror \
       /dev/disk/by-id/<DISK1-BY-ID> \
       /dev/disk/by-id/<DISK2-BY-ID>
   ```

#### Add Mirror Vdev

Add two new disks to existing storage pool `zdata`, as a mirror vdev:

   ```shell
   $ zpool add zdata mirror \
       /dev/disk/by-id/<DISK3-BY-ID> \
       /dev/disk/by-id/<DISK4-BY-ID>
   ```

#### Replace Failed Or Old Disk

##### Note Failed Or Old Disk ID

The failed (or old, removed) disk will show up like this, with `zpool status`:

   ```shell
   mirror-x                DEGRADED  0  0  0
     wwn-abc777def777ghi7  ONLINE    0  0  0
     14829562948105726384  UNAVAIL   0  0  0  was /dev/disk/by-id/wwn-stu666vwx666yzz6
   ```

##### Replace Disk

Remove the failed disk from the NAS. Put a new disk in the NAS in its place.
Note the `/dev/disk/by-id` of the new disk, e.g. `wwn-jkl888mno888pqr8`.
Activate the new disk:

   ```shell
   $ zpool replace zdata 14829562948105726384 /dev/disk/by-id/wwn-jkl888mno888pqr8
   ```

##### Expand Space

Once the `replace` operation is complete, if the vdev can now be expanded to
make use of larger disks in the vdev, tell zfs to expand the vdev's size:

   ```shell
   $ zpool online -e zdata /dev/disk/by-id/wwn-jkl888mno888pqr8
   ```

### ZFS Datasets

#### Add Dataset To Pool

##### Large-Files Dataset

Add a dataset to pool `zdata`, suited for storage of large (e.g. media) files:

   ```shell
   $ zfs create -o recordsize=1M -o compression=lz4 -o atime=off zdata/LargeFiles
   ```

##### Mixed-Files Dataset

Add a dataset to pool `zdata`, suited for storage of mixed (e.g. picture,
software, documents, etc) files:

   ```shell
   $ zfs create -o recordsize=128k -o compression=lz4 -o atime=off zdata/MixedFiles
   ```

### ZFS Snapshots

* Snapshots are enabled in the host's `default.nix`.
* See [`sanoid.nix`](../modules/apps/sanoid.nix) for guidance on working with
  snapshots.

## Source Code Layout

```
├─┬ nix_hosts/
│ │
│ ├─┬ hosts/
│ │ │
│ │ └─┬ xxx/                # config for a specific host
│ │   │
│ │   ├── default.nix       # configuration settings for the host
│ │   └── disko-config.nix  # disk provisioning for the host
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
│ ├── run.sh                # deploy NixOS to host, configure host, etc
│ │
```

## Contributing

* Feel free to report a bug or propose a feature by opening a new
  [Issue](https://github.com/digimokan/nix_hosts/issues).
* Follow the project's [Contributing](CONTRIBUTING.md) guidelines.
* Respect the project's [Code Of Conduct](CODE_OF_CONDUCT.md).

