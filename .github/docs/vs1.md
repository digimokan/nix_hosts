# vs1

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
    * [Hardware Parts List](#hardware-parts-list)
    * [Hardware Connections](#hardware-connections)
    * [Hardware BIOS Settings](#hardware-bios-settings)
    * [Hardware BMC Settings](#hardware-bmc-settings)
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
    * OS Boot Drives (see [Hardware Connections](#hardware-connections))
* [2x Intel 2TB D3-S4510 2.5 Inch Sata SSD](https://www.amazon.com/gp/product/B0H5KSZWTQ)
    * Data Drives (see [Hardware Connections](#hardware-connections))
* [1x Cable Matters VGA To HDMI Adapter](https://www.amazon.com/dp/B00IDFGK1W)
    * To PiKVM HDMI

### Hardware Connections

```
BACK OF PC
┌─────────────────────────────────────────────────────────────────────────┐
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                         │
│                 ┌─SER─┐  ┌────┐                                         │
│                 └─────┘  │ETH1│            ┌────┐                       │
│                          └────┘            │ETH2│                       │
│    ╭───╮ ╭──╮            ┌USB-A1┐ ┌USB-A3┐ └────┘                       │
│    │A/C│ │PWR   ┌─VGA─┐  └──────┘ └──────┘ ┌────┐                       │
│    ╰PWR╯ ╰SW╯   └─────┘  ┌USB-A2┐ ┌USB-A4┐ │ETH3│                       │
│                          └──────┘ └──────┘ └────┘                       │
└─────────────────────────────────────────────────────────────────────────┘
```

* `A/C PWR`: wall power
* `PWR SW`: on/off switch
* `SER`: serial (N/A)
* `VGA`: to PiKVM Vid Link (via VGA-HDMI Adapter)
* `ETH1`: BMC LAN (N/A)
* `USB-A1 (USB 2.0)`: N/A
* `USB-A2 (USB 2.0)`: to VGA-HDMI Adapter (power)
* `USB-A3 (USB 3.2 Gen 1)`: N/A
* `USB-A4 (USB 3.2 Gen 1)`: to PiKVM USB Link
* `ETH2`: LAN (N/A)
* `ETH3`: LAN to switch

```
FRONT OF PC
┌─────────────────────────────────────────────────────────────────────────┐
│                                        ┌─────HS-1─────┐ ┌─────HS-5─────┐│
│                                        └──────────────┘ └──────────────┘│
│                                        ┌─────HS-2─────┐ ┌─────HS-6─────┐│
│                                        └──────────────┘ └──────────────┘│
│                                        ┌─────HS-3─────┐ ┌─────HS-7─────┐│
│                                        └──────────────┘ └──────────────┘│
│                                        ┌─────HS-4─────┐ ┌─────HS-8─────┐│
│                                        └──────────────┘ └──────────────┘│
│                                                                         │
│                                                                         │
│                                                                         │
│                                                                ┌USB-A5┐ │
│                                        ╭──╮ ╭──╮               └──────┘ │
│                                        │PWR │RST   ┌┐┌┐┌┐┌┐┌┐  ┌USB-A6┐ │
│                                        ╰──╯ ╰──╯   └┘└┘└┘└┘└┘  └──────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

* Hot Swap Bays
    * `HS-1`: Crucial 500GB MX500
    * `HS-2`: Crucial 500GB MX500
    * `HS-3`: Intel 2TB D3-S4510
    * `HS-4`: Intel 2TB D3-S4510
    * `HS-5`: N/A
    * `HS-6`: N/A
    * `HS-7`: N/A
    * `HS-8`: N/A
* USB Ports
    * `USB-A5 (USB 3.0)`: N/A
    * `USB-A6 (USB 3.0)`: N/A

### Hardware BIOS Settings

#### Advanced

##### Network Stack Configuration

* `Network Stack`: "Disabled"

##### CPU Configuration

* `Power & Performance` -> `Boot Performance Mode`: "Max Non-Turbo Performance"
* `Power & Performance` -> `HDC Control` -> `Turbo Mode`: "Disabled"

#### Boot Devices

TODO

### Hardware BMC Settings

#### System

##### Component Info

* `Cooling` -> `Fan Mode`: "Full Speed"

## Configuration

* See [`vs1/zdata-zpool.nix`](../../hosts/vs1/zdata-zpool.nix) for the storage
  zpool (`zdata`) disk IDs, and for the list of `zdata` datasets.
* See [Deployed Usage](../README.md#deployed-usage) for info about initializing
  and managing the `zdata` zpool disks and datasets.

