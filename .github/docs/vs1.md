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
   * Coolers/Fans
       * CPU M-Cooler (`FAN1`): 1x [Noctua NH-L9i-17xx](https://www.amazon.com/Noctua-NH-L9i-17xx-Premium-Low-Profile-LGA1700/dp/B09HCLB7M3)
       * Front Intake (`FAN3`): 1x [NF-A8 PWM 12V](https://www.amazon.com/dp/B00NEMG62M)
       * Aft Exhaust1 (`FAN2`): 1x [Noctua NF-A4x20 PWM 12V](https://www.amazon.com/dp/B071W93333)
       * Aft Exhaust2 (`FAN5`): 1x [Noctua NF-A4x20 PWM 12V](https://www.amazon.com/dp/B071W93333)
       * Hot Swap Bay (`FANA`): 2x [Noctua NF-A4x10 PWM 12V](https://www.amazon.com/dp/B07DXRNYNX)
* [2x Crucial 500GB MX500 2.5 Inch Sata SSD](https://www.amazon.com/dp/B0786QNS9B)
   * OS Boot Drives (in 2 of the 8 2.5 Inch SSD Hotswap Bays)
* [2x Intel 2TB D3-S4510 2.5 Inch Sata SSD](https://www.amazon.com/gp/product/B0H5KSZWTQ)
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

