# nix_hosts

NixOS configuration to set up various machines.

[![Release](https://img.shields.io/github/release/digimokan/nix_hosts.svg?label=release)](https://github.com/digimokan/nix_hosts/releases/latest "Latest Release Notes")
[![License](https://img.shields.io/badge/license-MIT-blue.svg?label=license)](LICENSE.md "Project License")

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
* [Quick Start](#quick-start)
    * [Secret Management With SOPS](#secret-management-with-sops)
    * [Boot From Installer Image](#boot-from-installer-image)
    * [Bootstrap New Machine Or Disks](#bootstrap-new-machine-or-disks)
        * [Set Host Attributes](#set-host-attributes)
        * [Set Host Disks](#set-host-disks)
    * [Install NixOS To The Machine](#install-nixos-to-the-machine)
* [Source Code Layout](#source-code-layout)
* [Contributing](#contributing)

## Purpose

* Monorepo for NixOS configuration for various machines.
* Hosts may be on separate LANs.
* Hosts are all configured with ZFS-on-root (single-disk, or mirror).

## Hardware

* [`nas-0`](./docs/nas-0.md): main NAS on `GLAN`.

## Quick Start

### Secret Management With SOPS

See documentation in [`.sops.yaml`](../.sops.yaml).

### Boot From Installer Image

1. Download
   [NixOS Linux Distribution, Minimal ISO Image, 64-bit Intel/AMD](https://nixos.org/download/#download-nix).

2. Write the installer image to a
   [bootable USB stick](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux).

3. Insert the USB stick into the target machine.

4. Power up the target machine and
   [boot from the installer image](https://nixos.org/manual/nixos/stable/#sec-installation-booting).

   * Note: Per NixOS manual, try UEFI boot option first.
   * Note: Per NixOS manual, in the boot menu, select the default boot option.

### Bootstrap New Machine Or Disks

Required when a new machine is added to [`flake.nix`](../flake.nix), or a new or
replacement disk is put into a machine.

#### Set Host Attributes

Update the host's attribute set by obtaining the following
[`flake.nix`](../flake.nix) parameters from the target machine's minimimal
installer prompt:

1. `hostNameSel`: a hostname that must be unique, among all LANs.

2. `hostIdSel`: used by ZFS to uniquely identify ZFS pools.

   ```shell
   $ echo "<hostname>" | md5sum | cut -c1-8
   ```

3. `systemArchSel`: system architecture.

4. `isUefiSel`: whether the host's BIOS is a legacy-BIOS or UEFI-BIOS.

   ```shell
   $ [ -d /sys/firmware/efi ] && echo "BIOS is UEFI." || echo "BIOS is Legacy."
   ```

#### Set Host Disks

Update the host file in [`disk_ids`](../disk_ids/). The file should contain the
disk IDs of the disk(s) to be used for the machine's root pool.

On the target machine, at the minimimal installer prompt, obtain the disk IDs
by running this query:

   ```shell
   $ ls -l /dev/disk/by-id/
   ```

Multiple symlinks for the same disk will exist. Use these symlinks:

   * __SATA SSD and USB Enclosures__: use ID prefixed with `ata-`.

   * __NVME__: use ID prefixed with `nvme-eui.`.

   * __USB Drives (not in Enclosures)__: use ID prefixed with `usb-`.

### Install NixOS On The Machine

On the target machine, at the minimal installer prompt, format the disks
(as required), and install and configure NixOS:

   ```shell
   $ sudo ./install.sh <hostname>
   ```

## Source Code Layout

```
├─┬ nix_hosts/
│ │
│ ├── disk_ids/             # one file per host, each with the host's disk IDs
│ │
│ ├─┬ disko/                # disk partitioning for new disks, replacement disks
│ │ │
│ │ ├── zfs-mirror.nix      # ZFS root pool on two mirrored disks
│ │ └── zfs-single-disk.yml # ZFS root pool on single disk
│ │
│ ├─┬ hosts/                # config for different types of hosts
│ │ │
│ │ └── nas/                # config for a NAS host
│ │
│ ├── flake.lock            # locks the upstream repo states of flake.nix inputs
│ │
│ ├── flake.nix             # registry of hosts, repo sources, shared options
│ │
│ ├── install.sh            # formats disk(s) and installs NixOS on host
│ │
│ ├── nuke-disk.sh          # utility script to wipe a disk
│ │
```

## Contributing

* Feel free to report a bug or propose a feature by opening a new
  [Issue](https://github.com/digimokan/nix_hosts/issues).
* Follow the project's [Contributing](CONTRIBUTING.md) guidelines.
* Respect the project's [Code Of Conduct](CODE_OF_CONDUCT.md).

