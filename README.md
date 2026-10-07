<p align="center">
  <img src="logo.svg" alt="xone" width="180">
</p>

# xone Impulse Triggers

A small fork of [xone](https://github.com/dlundqvist/xone) that adds xpadneo-style
trigger rumble to Xbox One and Xbox Series controllers over USB.

Normal handle rumble works like stock xone. When a game sends regular Linux
`FF_RUMBLE`, the driver also drives the LT and RT motors based on how far each
trigger is pressed.

This is pressure-based trigger rumble. It does not add a new four-channel
force-feedback API.

## Tested

Confirmed on an official Xbox Series S|X controller over USB (`045e:0b12`).

- USB/GIP input
- normal rumble
- independent LT/RT motors
- trigger strength follows trigger pressure
- DKMS + Secure Boot with an enrolled DKMS MOK key

Bluetooth is still handled by [xpadneo](https://github.com/atar-axis/xpadneo).

## Install

### Fedora dependencies

```bash
sudo dnf install git dkms make kernel-devel kernel-headers curl bsdtar
```

For Fedora CachyOS kernels built with Clang/LTO, also install:

```bash
sudo dnf install clang llvm lld dwarves
```

Clone and install the driver:

```bash
git clone https://github.com/Firefoxray/xone-impulse-triggers.git
cd xone-impulse-triggers
sudo make install
```

`bsdtar` is required by the Xbox Wireless Dongle firmware installer. On Fedora
it is a separate package from `libarchive`, even though it uses libarchive.

If you already have the repo:

```bash
git pull
sudo make install
```

Reboot after installing.

xone blacklists the stock `xpad` driver because both drivers can claim the same
Xbox USB controller. On Fedora, if `xpad` still wins after a reboot:

```bash
sudo dracut -f
sudo reboot
```

## Secure Boot

The installer uses DKMS. If your DKMS MOK key is already enrolled, DKMS signs
the rebuilt modules automatically.

```bash
dkms status | grep xone
modinfo -F signer xone_gip_gamepad
modinfo -F signer xone_wired
```

## CachyOS / Clang kernels

Some Fedora CachyOS kernels are built with Clang/LTO. The DKMS installer detects
that and builds xone with `LLVM=1`.

For a manual build:

```bash
sudo dnf install clang llvm lld dwarves
make LLVM=1
```

## Check the USB path

```bash
grep -B2 -A12 -iE 'xbox|microsoft' /proc/bus/input/devices
```

A controller handled by xone should show something like:

```text
N: Name="Microsoft Xbox Controller"
P: Phys=gip0.0/input0
```

You can also check:

```bash
lsmod | grep -E 'xone|xpad'
```

For the wired xone path, `xone_gip_gamepad`, `xone_wired`, and `xone_gip`
should be loaded. Stock `xpad` should not be handling the controller.

## Test trigger rumble

On Fedora:

```bash
sudo dnf install linuxconsoletools
sudo fftest /dev/input/eventXXX
```

Hold LT or RT before starting a rumble effect. With neither trigger held, only
the main motors should run. Holding LT or RT should add vibration to that trigger.

## How it works

xone already has fields for four motors in the GIP rumble packet. Linux
`FF_RUMBLE` normally provides only the two main motor strengths.

This fork keeps those main values unchanged, remembers the current LT/RT
positions, and scales each trigger motor from the stronger main rumble value.

The behavior is based on xpadneo's pressure-controlled trigger rumble.

## Credits

Based on [xone](https://github.com/dlundqvist/xone), originally created by
[medusalix](https://github.com/medusalix/xone). Trigger-rumble behavior is based
on [xpadneo](https://github.com/atar-axis/xpadneo).

GPL-2.0-or-later.
