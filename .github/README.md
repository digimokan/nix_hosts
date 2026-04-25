# nix_nas_0

NixOS configuration to set up a 45HomeLab HL8 to serve as a BSD NAS.

[![Release](https://img.shields.io/github/release/digimokan/nix_nas_0.svg?label=release)](https://github.com/digimokan/nix_nas_0/releases/latest "Latest Release Notes")
[![License](https://img.shields.io/badge/license-MIT-blue.svg?label=license)](LICENSE.md "Project License")

## Table Of Contents

* [Purpose](#purpose)
* [Hardware Parts List](#hardware-parts-list)
* [Hardware Connections](#hardware-connections)
* [Hardware BIOS Configuration](#hardware-bios-configuration)
* [Quick Start](#quick-start)
    * [Download Installer Image](#download-installer-image)
* [Source Code Layout](#source-code-layout)
* [Contributing](#contributing)

## Purpose

Set up a [45HomeLab HL8](https://store.45homelab.com/configure/hl8) file server
to run NixOS and operate as a Network Attached Storage (NAS) server.

## Hardware Parts List

* [45HomeLab HL8](https://store.45homelab.com/configure/hl8)
    * Fully Built and Burned In
    * Ryzen 7 5700G CPU
    * 64 GB RAM
* [2x SanDisk SSD Plus 480GB 2.5 Inch Sata III SSD](https://www.amazon.com/dp/B01F9G46Q8)
    * OS Boot Drives
* [2x SABRENT 2.5 Inch SATA to USB 3.0 Drive Enclosure](https://www.amazon.com/dp/B00OJ3UJ2S)
    * Enclosures for Boot Drives, connected via USB
* [2x Western Digital WD Red Pro 22TB 3.5 Inch Internal Hard Drive](https://www.amazon.com/dp/B0B5W1CQ8W)
    * Initial storage drives
* [1x Cable Matters 3 Ft M-F USB Extension Cable](https://www.amazon.com/dp/B00C7S1B4W)
    * Bringing out USB port to front of PC

## Hardware Connections

```
                                  BACK OF PC
┌──────────────────────────────────────────────────────────────────────────────┐
│  ┌────────┐                        ╭───╮                                     │
│  │  AC    │                        │PWR│                                     │
│  │ADAPTER │                        ╰BTN╯                                     │
│  │        │                                                                  │
│  └────────┘                                                                  │
│                                                                              │
│                                                       ┌┐ LINE ┌┐ LINE ┌┐ MIC │
│                                                       └┘ IN   └┘ OUT  └┘     │
│                                                                              │
│                                                             ┌┐ WIFI   ┌┐ WIFI│
│                                                             └┘ ANT    └┘ ANT │
│                                                                              │
│                                                             ┌────┐ ┌──┐ ┌──┐ │
│                                                             │    │ │U │ │U │ │
│                                                             │ETH │ │S │ │S │ │
│                                                             │    │ │B │ │B │ │
│                                                             └────┘ └──┘ └──┘ │
│                                                                     A1   C1  │
│                                                                              │
│                                                                     ┌┐ QFLASH│
│                                                                     └┘ PLUS  │
│                                                                              │
│                                                                    ┌──┐ ┌──┐ │
│                                                                    │U │ │U │ │
│                                                                    │S │ │S │ │
│                                                                    │B │ │B │ │
│                                                                    └──┘ └──┘ │
│                                                                     A2   A3  │
│                                                                              │
│                                                               ┌──┐ ┌──┐ ┌──┐ │
│                                                               │U │ │U │ │U │ │
│                                                               │S │ │S │ │S │ │
│                                                               │B │ │B │ │B │ │
│                                                               └──┘ └──┘ └──┘ │
│                                                                A4   A5   A6  │
│                                                                              │
│                                                                  ┌──┐   ┌──┐ │
│                                                                  │D │   │H │ │
│                                                                  │S │   │D │ │
│                                                                  │P │   │M │ │
│                                                                  └──┘   └I─┘ │
│                                                                  DP-1  HDMI-1│
└──────────────────────────────────────────────────────────────────────────────┘
```

* Top Row
    * `LINE IN (3.5 mm)`: N/A
    * `LINE OUT (3.5 mm)`: N/A
    * `MIC IN (3.5 mm)`: N/A
* Second Row
    * `ETH`: ethernet to LAN
    * `A1 (USB-A 3.2)`: N/A
    * `C1 (USB-C 3.2)`: N/A
* Third Row
    * `A2 (USB-A 3.2)`: USB Extension Cable
    * `A3 (USB-A 3.2)`: PiKVM USB Link
* Fourth Row
    * `A4 (USB-A 3.2)`: OS Boot Drive 1
    * `A5 (USB-A 3.2)`: OS Boot Drive 2
    * `A6 (USB-A 3.2)`: N/A
* Graphics Card
    * `DP-1 (DisplayPort)`: N/A
    * `HDMI-1`: PiKVM Vid Link

## Hardware BIOS Configuration

* `Settings` -> `Platform Power`
    * `AC BACK`: "Always On"

## Quick Start

### Download Installer Image


1. Download the latest packages for the following packages onto a USB stick, by
constructing a URL with the appropriate FreeBSD version and package version.



#### Obtain Latest Quarterly Package Files For Realtek NIC

1. Download the latest packages for the following packages onto a USB stick, by
constructing a URL with the appropriate FreeBSD version and package version.

   * `pkg`
   * `realtek-re-kmod`

Note: find the package version in the "Packages" matrix of the package's
FreshPorts page, where "FreeBSD:nn:quarterly" and "amd64" intersect. The final
URL to access via a browser should look like this:

   ```
   https://pkg.freebsd.org/FreeBSD:NN:amd64/latest/All/realtek-re-kmod-NNNN.NN.NNNNNNN_N.pkg
   ```

#### Install Base System

1. Download the latest _RELEASE_ installer image for _amd64_ ("disc1") on the
   [FreeBSD Download Page](https://www.freebsd.org/where/).

2. Write the installer image to a USB stick, as described in
   [FreeBSD Handbook Installation Chapter](https://docs.freebsd.org/en/books/handbook/bsdinstall/#bsdinstall-pre).

3. Insert the USB stick into the target workstation PC, and boot from the
   FreeBSD installer image.

4. Follow guided installation. Select/enable __only__ these options:

    * Host Name: `nas-0.machine`.
        * Note: the control host will run the ansible playbook against this host
        * Note: FreeBSD requires `.machine` FQDN, but Tailscale removes suffix
    * ZFS guided installation: `mirror` (select the two Boot Drive disks).
    * Wireless Network configuration: do _not_ configure `rtw890`.

5. Remove the installer USB stick.

#### Install Realtek NIC And Configure DHCP

1. Reboot into the newly-installed system.

2. Insert the USB stick that contains the realtek NIC packages.

3. Create a directory to mount the USB stick on:

   ```shell
   $ mkdir /mnt/usbstick
   ```

## Source Code Layout

```
├─┬ nix_nas_0/
│ │
│ ├─┬ host_vars/
│ │ │
│ │ ├── vault_clear.yml   # proxy vars used by pb, point to vault_enc.yml vars
│ │ └── vault_enc.yml     # encrypted vault variables used by playbook.yml
│ │
│ ├─┬ roles/
│ │ │
│ │ └── ext/              # external (third-party, downloaded) roles
│ │
│ ├── ansible.cfg         # play-wide Ansible meta-config
│ ├── configure.sh        # configures the workstation, post-installation
│ ├── hosts               # Ansible inventory (playbook runs on these hosts)
│ ├── playbook.yml        # main Ansible playbook
│ ├── requirements.yml    # list of roles (on github/galaxy) to download
│ └── vault_password.txt  # password-string to encrypt and decrypt vault vars
│
```

## Contributing

* Feel free to report a bug or propose a feature by opening a new
  [Issue](https://github.com/digimokan/nix_nas_0/issues).
* Follow the project's [Contributing](CONTRIBUTING.md) guidelines.
* Respect the project's [Code Of Conduct](CODE_OF_CONDUCT.md).

