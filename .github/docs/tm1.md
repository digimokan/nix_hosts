# tm1

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
   * [Hardware Parts List](#hardware-parts-list)
   * [Hardware Connections](#hardware-connections)
   * [Hardware BIOS Configuration](#hardware-bios-configuration)
* [Configuration](#configuration)

## Purpose

`tm1` is an [Intel NUC5CPYH NUC](https://www.intel.com/content/www/us/en/products/sku/85254/intel-nuc-kit-nuc5cpyh/specifications.html)
that functions as a test machine for a basic desktop user.

## Hardware

### Hardware Parts List

* [1x Intel NUC5CPYH NUC](https://www.amazon.com/Intel-NUC5CPYH-Graphics-2-5-Inch-BOXNUC5CPYH/dp/B00XPVRR5M/)
   * Celeron 2.16 GHz CPU
   * Intel HD Graphics (Braswell/Gen 8 architecture)
* [1x Crucial 8GB DDR3L RAM](https://www.amazon.com/Crucial-Single-PC3-12800-Unbuffered-204-Pin/dp/B006YG8X9Y/)
   * Single RAM Stick
* [1x SanDisk 16GB Ultra Fit USB 3.1 Flash Drive](https://www.amazon.com/dp/B077Y149DL)
   * OS Boot Drive
* [1x Intel 530 Series 240GB 2.5 Inch Sata III SSD](https://www.amazon.com/Intel-240GB-Internal-Solid-SSDSC2BW240A401/dp/B018HKRHN2/)
   * User Data Drive
* [1x LG 28MQ780-B 28 Inch SDQHD 2560x2880 DualUp Monitor](https://www.amazon.com/dp/B09XTD5C7H)
   * Connected over HDMI
* [1x Cable Matters Ultra Mini 4 Port USB 3.0 Hub, x 2](https://www.amazon.com/dp/B00PHPWLPA)
   * For keyboard, mouse, webcam
* [1x EMEET C980 Pro Webcam With Built-In Speakers And Mic](https://www.amazon.com/dp/B088BY9PJG)
   * Placed on monitor
* [1x Redgraon GS560 Powered Speaker](https://www.amazon.com/dp/B08X6LYPHK)
   * USB for power input, 3.5 mm for sound output
* [1x Evoluent VMCRW Wireless Vertical Mouse](https://www.amazon.com/dp/B01BNZAY6A)
   * Connected over USB
* [1x Logitech G413 SE Full Size Mechanical Gaming Keyboard](https://www.amazon.com/dp/B08Z6X4NK3)
   * Connected over USB

### Hardware Connections

```
BACK OF PC
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│    ╭───╮                ┌────┐    ┌────┐   ┌USB-A1┐    │
│    │A/C│   ┌┐ TOSLINK  ┌┘HDMI└┐   │ETH │   └──────┘    │
│    ╰PWR╯   └┘ 3.5 MM   └──────┘   └────┘   ┌USB-A2┐    │
│                                            └──────┘    │
│            ┌──VGA───┐                                  │
│            └────────┘                                  │
│                                                        │
└────────────────────────────────────────────────────────┘
```

* `A/C PWR`: wall power
* `TOSLINK & 3.5 mm Stereo`: speaker output
* `HDMI`: to monitor
* `ETH`: ethernet to LAN
* `USB-A1 (USB 3.0)`: USB Hub, with keyboard, mouse, webcam
* `USB-A2 (USB 3.0)`: speaker power

```
FRONT OF PC
┌────────────────────────────────────────────────────────┐
│                                                        │
│                                                        │
│                      ┌USB-A3┐  ┌┐ PHONES               │
│                      └──────┘  └┘ MIC                  │
│                      ┌USB-A4┐     3.5 MM               │
│                      └──────┘                          │
│                                                        │
│                                                        │
│                                                        │
└────────────────────────────────────────────────────────┘
```

* `USB-A3 (USB 3.0, Yellow, Always-On)`: N/A
* `USB-A4 (USB 3.0)`: OS USB Stick
* `HEADPHONES / MIC 3.5 mm`: N/A

### Hardware BIOS Configuration

#### General Settings

* TODO....
* `Settings` -> `Platform Power`
* `AC BACK`: "Always On"

#### Boot Devices

TODO....

Once NixOS has been installed to the two mirrored drives:

* `Boot` -> `Boot Option Priorities`: ensure the two `UEFI OS (SABRENT)`
  entries are at the top of the list. Set all other enries to `Disabled`.

## Configuration

TODO....

* See [`nas/default.nix`](../../hosts/nas/default.nix) for info about the
storage zpool expected to reside on the HL8s storage disks.
* See [`nas/default.nix`](../../hosts/nas/default.nix) for info about the
datasets expected to exist on the storage zpool.
* See [ZFS Storage Pools](../README.md#zfs-storage-pools) for info about
creating the storage zpool.
* See [ZFS Datasets](../README.md#zfs-datasets) for info about creating
datasets.

