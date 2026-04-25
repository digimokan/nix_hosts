# nix_hosts

NixOS configuration to set up various machines.

[![Release](https://img.shields.io/github/release/digimokan/nix_hosts.svg?label=release)](https://github.com/digimokan/nix_hosts/releases/latest "Latest Release Notes")
[![License](https://img.shields.io/badge/license-MIT-blue.svg?label=license)](LICENSE.md "Project License")

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
* [Quick Start](#quick-start)
    * [Boot From Installer Image](#boot-from-installer-image)
    * [Bootstrap New Machine Or Disks](#bootstrap-new-machine-or-disks)
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

### Boot From Installer Image

1. Download
   [NixOS Linux Distribution, Minimal ISO Image, 64-bit Intel/AMD](https://nixos.org/download/#download-nix).

2. Write the installer image to a
   [bootable USB stick](https://nixos.org/manual/nixos/stable/#sec-booting-from-usb-linux).

3. Insert the USB stick into the NAS machine.

4. Power up the NAS and
   [boot from the installer image](https://nixos.org/manual/nixos/stable/#sec-installation-booting).

   * Note: Per NixOS manual, try UEFI boot option first.
   * Note: Per NixOS manual, in the boot menu, select the default boot option.

### Bootstrap New Machine Or Disks

Required when a new machine is added to [`flake.nix`](./flake.nix), or a new or
replacement disk is put into a machine.

Update the host's attribute set by obtaining the following
[`flake.nix`](./flake.nix) parameters at the minimimal installer prompt:

1. `hostnameSel`: a hostname that must be unique, among all LANs.

2. `hostIdSel`: used by ZFS to uniquely identify ZFS pools.

   ```shell
   $ echo "<hostname>" | md5sum | cut -c1-8
   ```

3. `systemArchSel`: system architecture.

4. `isUefiSel`: whether the host's BIOS is a legacy-BIOS or UEFI-BIOS.

   ```shell
   $ [ -d /sys/firmware/efi ] && echo "BIOS is UEFI." || echo "BIOS is Legacy."
   ```

5. `rootPoolDisksSel`: unique S/N IDs for serial-numbered disks in ZFS root pool.

   ```shell
   $ ls -l /dev/disk/by-id/
   ```

### Install NixOS To The Machine

1. Set required host environment vars:

   ```shell
   $ REPO_SEL="github:digimokan/nix_hosts"
   ```

   ```shell
   $ HOSTNAME_SEL="<hostname from flake.nix>"
   ```

   ```shell
   $ [ -d /sys/firmware/efi ] && UEFI_SEL="--write-efibootmgr" || UEFI_SEL=""
   ```

2. Format the disks (as required), and install and configure NixOS:

   ```shell
   $ sudo nix run github:nix-community/disko#disko-install -- \
       --flake "${REPO_SEL}#${HOSTNAME_SEL}" \
       "${UEFI_SEL}"
   ```

## Source Code Layout

```
├─┬ nix_hosts/
│ │
│ ├── flake.nix             # registry of hosts, repo sources, shared options
│ │
│ ├─┬ disko/                # disk partitioning for new disks, replacement disks
│ │ │
│ │ ├── zfs-mirror.nix      # ZFS root pool on two mirrored disks
│ │ └── zfs-single-disk.yml # ZFS root pool on single disk
│ │
│ └─┬ hosts/                # config for different types of hosts
│   │
│   └── nas/                # config for a NAS host
│
```

## Contributing

* Feel free to report a bug or propose a feature by opening a new
  [Issue](https://github.com/digimokan/nix_hosts/issues).
* Follow the project's [Contributing](CONTRIBUTING.md) guidelines.
* Respect the project's [Code Of Conduct](CODE_OF_CONDUCT.md).

