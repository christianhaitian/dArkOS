# <p align="center">SOLIS base OS</p>

### <p align="center">A stripped-down Debian image builder for RK3326 handhelds, repurposed as the base for the SOLIS Rust music tracker.</p>

This project started life as [dArkOS](https://github.com/Sinkopa-AV/dArkOS-ultralight) (itself a Debian rebuild of [ArkOS](https://github.com/christianhaitian/arkos/wiki)). It has been reduced to a minimal base OS for the **SOLIS** music tracker. All of the retro-gaming stack has been removed.

## What this image is

A small Debian (trixie) arm64 image for RK3326 devices that boots to a multi-user console, brings up audio/MIDI and networking, and starts the SOLIS service. SOLIS itself is a placeholder for now.

### Kept
- Kernel + device tree for RK3326 (g350, rg351mp, rgb10, a10mini)
- U-Boot
- ALSA + audio drivers, `.asoundrc` routing, USB DAC support
- Display / DRM (KMS) drivers
- evdev input drivers
- WiFi firmware (rtl8723ds + `firmware-mediatek`) and NetworkManager
- systemd (stripped down) + SSH (enabled)

### Added
- **SOLIS** as a systemd service (`solis.service`) — currently a placeholder launcher at `/usr/local/bin/solis`. Replace that file with the real Rust binary.
- MIDI dependencies: `libasound2`, `alsa-utils`
- Rust runtime: `rustc`, `cargo`

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

# Credits and Thanks
Built on the work of [ArkOS](https://github.com/christianhaitian/arkos/wiki) and dArkOS by christianhaitian and contributors.
