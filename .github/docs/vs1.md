# vs1

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
   * [Hardware Parts List](#hardware-parts-list)
   * [Hardware Connections](#hardware-connections)
   * [Hardware BIOS Configuration](#hardware-bios-configuration)
* [Configuration](#configuration)

## Purpose

`vs1` is an [ABMX Mini-Server](https://www.abmx.com/small-2u-short-depth-server)
that hosts services, containers, and virtual machines.

## Hardware

### Hardware Parts List

* [ABMX 214LPS3CH-F243 2U Mini-Server](https://www.abmx.com/small-2u-short-depth-server)
   * 14 Inches Deep
   * Supermicro X13SCH-F LGA-1700 Motherboard
   * Intel 6369P Xeon 3.3GHz 8-Core, 16-Thread CPU
   * 32 GB DDR5 ECC Unbuffered RAM (Upgradable to 128 GB)
   * TPM 2.0 Trusted Platform Module (TCG 2.0)
   * FSP Group 9PA500CN04 Power Supply
* [2x SanDisk 500GB SSD Plus 2.5 Inch Sata III SSD](https://www.amazon.com/gp/product/B0F4Y2VR8S)
   * OS Boot Drives (in 2 of the 8 2.5 Inch SSD Hotswap Bays)
* [2x Samsung 2TB 870 EVO 2.5 Inch Sata III SSD](https://www.amazon.com/dp/B08QB93S6R)
   * Data Drives (in 2 of the 8 2.5 Inch SSD Hotswap Bays)

### Hardware Connections

TODO

### Hardware BIOS Configuration

#### Advanced

##### Network Stack Configuration

* `Network Stack`: "Disabled"

##### CPU Configuration

* `Power & Performance` -> `Boot Performance Mode`: "Max Non-Turbo Performance"
* `Power & Performance` -> `HDC Control` -> `Turbo Mode`: "Disabled"

#### Boot Devices

TODO

## Configuration

* See [`vs1/zdata-zpool.nix`](../../hosts/vs1/zdata-zpool.nix) for the storage
  zpool (`zdata`) disk IDs, and for the list of `zdata` datasets.
* See [Deployed Usage](../README.md#deployed-usage) for info about initializing
  and managing the `zdata` zpool disks and datasets.

