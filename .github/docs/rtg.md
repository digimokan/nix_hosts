# rtg1, rtg2

## Table Of Contents

* [Purpose](#purpose)
* [Hardware](#hardware)
   * [Hardware Parts List](#hardware-parts-list)
   * [Hardware Connections](#hardware-connections)

## Purpose

`rtg1` and `rtg2` are [Protectli FW2B](https://www.amazon.com/dp/B07G7GW2FB)
edge routers that operate in a high availability setup.

## Hardware

### Hardware Parts List

* 1x [Protectli FW2B](https://www.amazon.com/dp/B07G7GW2FB)
    * Intel Celeron J3060 1.6 GHz, 2 Cores
    * AES-NI hardware support
* 1x [Crucial 8 GB DDR3 1600 MHz RAM](https://www.amazon.com/gp/product/B006YG8X9Y)
    * Install first
* 1x [Transcend 512 GB mSATA SSD](https://www.amazon.com/gp/product/B0BLF29WNS)
    * Install second, in _top_ SSD slot (see slot layout in
      [Protectli Hardware Overview](https://kb.protectli.com/kb/fw2b-fw4b-series-hardware-overview)).

### Hardware Connections

```
BACK OF PC
┌─┐                                                   ┌─┐
│ │                                                   │ │
│ └───────────────────────────────────────────────────┘ │
│                                                       │
│     ┌USB-A1┐  ┌USB-A3┐  ┌────┐  ┌────┐         ╭───╮  │
│     └──────┘  └──────┘  │ETH1│  │ETH2│         │A/C│  │
│     ┌USB-A2┐  ┌USB-A4┐  └────┘  └────┘         ╰PWR╯  │
│     └──────┘  └──────┘                                │
└───────────────────────────────────────────────────────┘
```

* `USB-A1 (USB 2.0)`: N/A
* `USB-A2 (USB 2.0)`: N/A
* `USB-A3 (USB 2.0)`: N/A
* `USB-A4 (USB 2.0)`: N/A
* `ETH1`: ethernet to LAN switch
* `ETH2`: ethernet to WAN modem
* `A/C PWR`: wall power

```
FRONT OF PC
┌─┐                                                   ┌─┐
│ │                                                   │ │
│ └───────────────────────────────────────────────────┘ │
│   ╭──╮  ╭─╮  ┌USB-A5┐  ┌────┐   ┌────┐    ┌────┐      │
│   ╰PWR  ╰AD  └──────┘  │COM1│  ┌┘HDMI1┐  ┌┘HDMI2┐     │
│              ┌USB-A6┐  └────┘  └──────┘  └──────┘     │
│              └──────┘                                 │
└───────────────────────────────────────────────────────┘
```

* `PWR`: on/off button
* `AD`: 3.5 mm audio jack (N/A)
* `USB-A5 (USB 3.0)`: N/A
* `USB-A6 (USB 3.0)`: to PiKVM USB Link
* `COM1`: RJ45 serial (N/A)
* `HDMI1`: N/A
* `HDMI2`: to PiKVM Vid Link

