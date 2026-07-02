# <p align="center">SOLIS base OS</p>

### <p align="center">A stripped-down Debian image builder for RK3326 handhelds, repurposed as the base for the SOLIS Rust music tracker.</p>

This project started life as [dArkOS](https://github.com/christianhaitian/dArkOS) by christianhaitian (itself a Debian rebuild of [ArkOS](https://github.com/christianhaitian/arkos/wiki)). It has been reduced to a minimal base OS for the **SOLIS** music tracker. All of the retro-gaming stack has been removed.

## What this image is

A small Debian (trixie) arm64 image for RK3326 devices that boots to a multi-user console, brings up audio/MIDI and networking, and starts the SOLIS service. SOLIS itself is a placeholder for now.

### Kept
- Kernel + device tree for RK3326 (g350, rg351mp, rgb10, a10mini)
- U-Boot
- ALSA + audio drivers, `.asoundrc` routing, USB DAC support
- Display / DRM (KMS) drivers
- evdev input drivers
- WiFi firmware (rtl8723ds + `firmware-mediatek`, for USB dongles — the G350 has no onboard WiFi) and NetworkManager
- systemd (stripped down) + SSH (enabled)

### Added
- **SOLIS** as a systemd service (`solis.service`) — currently a placeholder launcher at `/usr/local/bin/solis`. Replace that file with the real Rust binary (cross-compiled; no toolchain ships on-device).
- Audio/MIDI runtime: `libasound2`, `alsa-utils`, `libsdl2-2.0-0` (SOLIS's audio path)
- **USB-C deploy link** (g350): `usbnet.service` brings up a CDC-ECM gadget at boot — device is `192.168.7.1`, `ssh ark@192.168.7.1` (password `ark`). The port has one role per boot: `usbmode.sh host|gadget` switches between the deploy link (default) and USB host mode (drives / MIDI keyboards / WiFi dongles), or copy `rk3326-g350-linux.dtb.host` / `.gadget` over `rk3326-g350-linux.dtb` on the BOOT partition from any computer.

### Removed
- EmulationStation, RetroArch + all emulator cores, every standalone emulator
- PortMaster, OGage daemon, Kodi
- Game scraper / metadata services, ES theme system
- Mesa / OpenGL ES (libMali) stack
- ROM folder structure (the third partition is now a generic `/data` partition)
- Gaming-specific systemd services and the OTA updater (a SOLIS-specific updater will be added later)
- 32-bit (armhf) userspace (was only for 32-bit ports)

## Building

Suggested environment: Ubuntu 24.04 or newer. WSL is not supported (no chroot). The build makes heavy use of `sudo`; passwordless sudo is recommended (`./FreeSudo.sh` or a sudoers `NOPASSWD` line).

Build for a device with `make <target>`:

```
make g350
make rg351mp
make rgb10
make a10mini
```

**Notes**
- To build on a different Debian release, change `DEBIAN_CODE_NAME` in the Makefile or pass `DEBIAN_CODE_NAME=<release>` to `make`.
- The third partition is created empty, labeled `SOLISDATA`, and converted to exfat and mounted at `/data` on first boot (alongside rootfs expansion).

## First boot

Flash the image to an SD card, insert, power on. First boot expands the rootfs and converts the `SOLISDATA` partition to exfat, reboots itself once, then starts SOLIS (the placeholder for now). No keyboard or login is ever needed on the device — its screen belongs to SOLIS.

## Connecting (SSH over the USB-C cable)

The image boots with the USB-C port in **gadget** mode: plug it into a Mac/PC and the device shows up as a network interface named "g350 Console" while it **charges over the same cable**.

One-time Mac setup: System Settings → Network → g350 Console → Details → TCP/IP → Configure IPv4 **Manually**, IP `192.168.7.2`, mask `255.255.255.0`, no router.

Then, from the Mac:

```
ssh ark@192.168.7.1        # password: ark — typed on the Mac, never on the handheld
ssh-copy-id ark@192.168.7.1   # optional, once: no password ever again
```

## Deploying SOLIS

Cross-compile for `aarch64-unknown-linux-gnu`, then:

```
scp target/aarch64-unknown-linux-gnu/release/solis ark@192.168.7.1:/tmp/solis
ssh ark@192.168.7.1 'sudo systemctl stop solis && sudo mv /tmp/solis /usr/local/bin/solis && sudo systemctl start solis'
```

Logs: `ssh ark@192.168.7.1 journalctl -u solis -f`. Fonts and project data live on `/data/SOLIS` (the exfat partition — also readable by any computer via an SD reader).

## USB-C roles

The port does one role per boot (single PHY, no OTG negotiation on this board):

| Mode | What works | Power |
|------|-----------|-------|
| `gadget` (default) | SSH/deploy link at 192.168.7.1 | device **charges** from the cable |
| `host` | USB drives, class-compliant USB-MIDI keyboards, WiFi dongles | device **powers** the peripherals from its battery |

Switch with `usbmode.sh host` / `usbmode.sh gadget` on the device (reboots to apply), or from any computer by copying `rk3326-g350-linux.dtb.host` or `.gadget` over `rk3326-g350-linux.dtb` on the FAT32 `BOOT` partition. Don't plug the device into a computer while in host mode — two hosts, no link, no charge.

# Credits and Thanks
Built on the work of [ArkOS](https://github.com/christianhaitian/arkos/wiki) and dArkOS by christianhaitian and contributors.
