# nas

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
   * [Hardware Parts List](#hardware-parts-list)
   * [Hardware Connections](#hardware-connections)
   * [Hardware BIOS Configuration](#hardware-bios-configuration)
* [Configuration](#configuration)

## Purpose

`nas` is a [45HomeLab HL8](https://store.45homelab.com/configure/hl8) that
serves up files over NFS.

## Hardware

### Hardware Parts List

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

### Hardware Connections

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

### Hardware BIOS Configuration

#### General Settings

* `Settings` -> `Platform Power`
* `AC BACK`: "Always On"

#### Boot Devices

Once NixOS has been installed to the two mirrored drives:

* `Boot` -> `Boot Option Priorities`: ensure the two `UEFI OS (SABRENT)`
  entries are at the top of the list. Set all other enries to `Disabled`.

## Configuration

* See [`nas/default.nix`](../../hosts/nas/default.nix) for info about the
storage zpool expected to reside on the HL8s storage disks.
* See [`nas/default.nix`](../../hosts/nas/default.nix) for info about the
datasets expected to exist on the storage zpool.
* See [ZFS Storage Pools](../README.md#zfs-storage-pools) for info about
creating the storage zpool.
* See [ZFS Datasets](../README.md#zfs-datasets) for info about creating
datasets.

