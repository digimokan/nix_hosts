# tm2

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
   * [Hardware Parts List](#hardware-parts-list)
   * [Hardware Connections](#hardware-connections)
   * [Hardware BIOS Configuration](#hardware-bios-configuration)
* [Configuration](#configuration)

## Purpose

`tm2` is an [Beelink Mini S12 Pro N100](https://www.amazon.com/dp/B0GQRT4YT3/)
that functions as a test machine for a basic desktop user.

## Hardware

### Hardware Parts List

* [1x Beelink Mini S12 Pro N100](https://www.amazon.com/dp/B0GQRT4YT3/)
   * Intel Alder Lake-N N100 3.4 GHz, 4 Cores, 4 Threads CPU
   * 16GB DDR4 RAM
   * 500GB M.2 SATA SSD, pre-installed in M.2 SATA slot (for `zroot` zpool)
* [1x Western Digital 250GB Red SN700 PCIe Gen3 M.2 2280 SSD](https://www.amazon.com/gp/product/B09H1653PD/)
   * Install in open M.2 PCIe slot (for `zdata` zpool)
* [1x ELP 4K USB Camera With Microphone](https://www.amazon.com/gp/product/B0CBM6Z7MG/)
   * To test camera and microphone functionality

### Hardware Connections

```
BACK OF PC
┌───────────────────────────────────────────────────────┐
│                                                       │
│                                                       │
│    ┌USB-A1┐   ┌────┐    ┌────┐     ┌────┐    ╭───╮    │
│    └──────┘   │ETH │   ┌┘HDMI1┐   ┌┘HDMI2┐   │A/C│    │
│    ┌USB-A2┐   └────┘   └──────┘   └──────┘   ╰PWR╯    │
│    └──────┘                                           │
│                                                       │
│                                                       │
└───────────────────────────────────────────────────────┘
```

* `USB-A1 (USB 3.2 Gen2)`: to PiKVM USB Link
* `USB-A2 (USB 3.2 Gen2)`: to ELP USB Camera
* `ETH`: ethernet to LAN
* `HDMI1`: to PiKVM Vid Link
* `HDMI2`: N/A
* `A/C PWR`: wall power

```
FRONT OF PC
┌───────────────────────────────────────────────────────┐
│                                                       │
│                                                       │
│                                                       │
│       ┌USB-A3┐    ┌USB-A4┐   ┌┐ PHONES   ┌─┐ PWR      │
│       └──────┘    └──────┘   └┘ MIC      └─┘ BTN      │
│                                                       │
│                                                       │
│                                                       │
└───────────────────────────────────────────────────────┘
```

* `USB-A3 (USB 3.2 Gen2)`: N/A
* `USB-A4 (USB 3.2 Gen2)`: N/A
* `HEADPHONES / MIC 3.5 mm`: N/A
* `PWR BTN`: on/off button

### Hardware BIOS Configuration

#### Advanced

#### General Settings

* `Connectivity Configuration` -> `Wi-Fi Core`: "Disabled"
* `Connectivity Configuration` -> `BT Core`: "Disabled"

#### Boot

* `Setup Prompt Timeout`: 3
* `FIXED BOOT ORDER Priorities` -> `Boot Option #1`: "Hard Disk:NixOS-boot"

