# <p align="center">Welcome to dArkOS</p>

### <p align="center">Debian based version of the ArkOS operating system for select RK3326 and RK3566 based portable gaming devices.</p>

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/donate?hosted_button_id=RC72LJ4SSERSU)

The overarching goals of dArkOS is as follows:
1. Highly customizable 
1. Performance
1. Online Updates (Won't require SD card reflashing unless there are major structural changes like file system changes.)
1. Enthusiats focused

This is intended to continue the work from [ArkOS](https://github.com/christianhaitian/arkos/wiki) but in a way that allows others to easily fork and modify the OS to their own taste.  If there's a feature not currently available that you want, you can fork this and add it yourself.
Don't feel like building the OS from scratch or don't have the resources to do so?  Ok, just download one of the available prebuilt images and make changes right in the OS.  Since this OS is based on the latest stable version of Debian, you have
access to over 64,000 packages you can install via the Debian Advanced Package Tool (APT).  Want to build the latest testing or bleeding edge release of Debian? See the notes below on how to accomplish this.

**Building instructions:**
   - Suggested Environment - Ubuntu or related variants, version 24.04 or newer.  Windows Subsystem for Linux (WSL) is not supported and will not work due to no support for chroot. \
     Because chroot is used in this process, heavy use of sudo is made.  To reduce the possibility of priviledge issues, \
     it's best to be able to execute sudo without needing a password.  This can be done using one of the 2 methods below.
      - Method 1: - Open a Terminal window and type `sudo visudo` \
                    In the bottom of the file, add the following line: `$USER ALL=(ALL) NOPASSWD: ALL` \
                    Where $USER is your username on your system. Save and close the sudoers file (if you haven't changed your \
                    default terminal editor (you'll know if you have), press Ctl + x to exit nano and it'll prompt you to save).
      - Method 2: - Clone this git repo then run `./FreeSudo.sh`.  If there were no errors, it should've completed this change for you. \
                    You can verify this by checking if a `/etc/sudoers.d/$USER` file exists and contains `$USER ALL=(ALL) NOPASSWD: ALL` in it.
     
Now you should be able to just run make <device_name> to build for a supported device.  Example: `make rg353`

**Notes**
- To build on a different release of Debian, change the DEBIAN_CODE_NAME export in the Makefile or add DEBIAN_CODE_NAME=<release> as a variable to `make`.  Other debian code names can be found at https://www.debian.org/releases/
- By default, this will build with both a 64bit and 32bit userspace.  This is primarily to support some 32bit ports available through PortMaster.  There are also some 32bit retroarch emulators available but the performance seems to be similar to the 64bit retroarch emulators at this point.
 - To build without 32bit support, change the BUILD_ARMHF export in the Makefile to n or add BUILD_ARMHF=n as a variable to `make`.
- For RK3566, you can add Kodi to your build.  Just change the BUILD_KODI export in the Makefile to y or add BUILD_KODI=y as a variavble to `make`.  Kodi is also available as a prepackaged build in the extra_packages/rk3566 subfolder.  Just copy it to your tools folder and launch from Options/Tools in the start menu.
 - Be aware that building Kodi will add a significant amount of time to your build.  Could be double or triple the build time.
- Initial build time on an Intel I7-8700 65w unit with a 512GB NVME SSD and 32GB of DDR4 memory is a little over 19 hours.  Subsequent builds are about 3 hours thanks to ccache.

# Credits and Thanks
[ChatGPT](https://chatgpt.com/) for guidance on how to build a Debian image \
Jetup13 for many themes \
dani7959 for the replica theme \
pix33l for the pixui theme \
TheGreatCrippler for testing and feedback \
kloptops for testing and feedback \
Fraxinus88 for testing and feedback \
ImCoKeMaN for testing and feedback \
[PortMaster](https://portmaster.games/) team for support in figuring out PM interface issues
