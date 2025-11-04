Arduino UNO Q
=============

Intro
=====

This configuration provides support for the Arduino UNO Q board (codename "Imola"),
Arduino's first Linux-capable board. The Arduino UNO Q features a Qualcomm QRB2210
SoC based on QCM2290, with a quad-core ARM Cortex-A53 processor, Adreno 702 GPU,
and 2-4GB of RAM.

This configuration builds a minimal BusyBox-based system with support for the base
board and optional device tree overlays for accessories (GigaDisplay, Raspberry Pi
Camera v2, and ODD carrier board).

Board specifications:
- SoC: Qualcomm QRB2210 (QCM2290-based)
- CPU: 4x ARM Cortex-A53
- GPU: Adreno 702
- RAM: 2GB or 4GB
- WiFi: WCN3988
- Bluetooth: WCN3988

Arduino UNO Q product page:
https://store.arduino.cc/products/uno-q

This configuration uses:
- Arduino's custom kernel fork (v6.16.7) from: https://github.com/arduino/linux-qcom
- Arduino's U-Boot fork (qcom-mainline branch) from: https://github.com/arduino/u-boot

The board uses Qualcomm's proprietary bootloader chain (XBL, TZ, ABL) with U-Boot
chainloaded after ABL via an Android boot image.

How to build
============

    $ make arduino_uno_q_defconfig
    $ make

Note: You will need internet access to download the required sources,
including the Arduino kernel and U-Boot from GitHub.

Files created in output directory
==================================

output/images/
├── boot.img                                    (U-Boot packaged as Android boot image)
├── boot.scr                                    (U-Boot boot script)
├── u-boot.bin                                  (U-Boot bootloader binary)
├── Image                                       (Linux kernel)
├── qrb2210-arduino-imola.dtb                  (Base board device tree)
├── qrb2210-arduino-imola-gigadisplay.dtbo     (GigaDisplay overlay)
├── qrb2210-arduino-imola-camera-rpiv2.dtbo    (RPi Camera v2 overlay)
├── qrb2210-arduino-imola-odd.dtbo             (ODD carrier overlay)
├── efi.vfat                                    (EFI partition with kernel and DTBs)
├── rootfs.ext2                                 (Root filesystem)
├── rootfs.ext4 -> rootfs.ext2
└── deploy/                                     (All files needed for deployment)

Boot Architecture
=================

The Arduino UNO Q uses a U-Boot chainloading architecture:

    Power On → XBL (Primary Boot) → TZ (TrustZone) → ABL (Android Boot Loader)
             → U-Boot (from boot.img) → Linux Kernel (from EFI partition)

The boot flow works as follows:

1. ABL loads boot.img (containing U-Boot + device tree) from boot_a partition
2. U-Boot initialises and loads boot.scr from the EFI partition (part 67)
3. boot.scr loads the Linux kernel and device tree from the EFI partition
4. Kernel boots with rootfs mounted from partition 68

The EFI partition layout:
- boot.scr: U-Boot boot script
- Image: Linux kernel (40MB)
- qrb2210-arduino-imola.dtb: Device tree
- *.dtbo: Device tree overlays for accessories

Flashing the System
===================

The deployment package includes a flash script that uses qdl (Qualcomm Download)
to flash the complete system via EDL (Emergency Download) mode.

Prerequisites:
1. Install qdl tool (built by Buildroot as host tool)
2. Boot board into EDL mode (hold button during power-on)

To flash:

    $ cd output/images/deploy
    $ sudo ./flash.sh

The flash script will write:
- boot.img to boot_a partition (part 11) - U-Boot bootloader
- efi.img to efi partition (part 67) - Kernel and device trees
- rootfs.img to rootfs partition (part 68) - Root filesystem

The script includes safety checks and will prompt for confirmation before flashing.

Serial Console
==============

The serial console is available on UART4 (ttyMSM0) at 115200 baud, 8N1.
Check Arduino's documentation for the physical location of the serial pins.

Both U-Boot and Linux output to this console. You can interrupt the U-Boot
boot sequence by pressing SPACE during the 3-second countdown.

Firmware Requirements
=====================

The QRB2210 SoC requires several firmware files for full functionality.
This configuration includes all required firmware via linux-firmware:

BR2_PACKAGE_LINUX_FIRMWARE_QCOM_QCM2290=y includes:
  - qcom/qcm2290/a702_zap.mbn (GPU - Adreno 702)
  - qcom/qcm2290/adsp.mbn (Audio DSP)
  - qcom/qcm2290/modem.mbn (Modem)
  - Configuration JSON files

WiFi/Bluetooth firmware for WCN3988 is also included in the linux-firmware package.
All firmware files are automatically installed to /lib/firmware/qcom/qcm2290/

EDL Firehose Programmer
=======================

The Qualcomm EDL (Emergency Download) firehose programmer (prog_firehose_ddr.elf)
is required for flashing the board via qdl. This proprietary, OEM-signed binary
(588KB) is automatically downloaded as part of the host-qdl package build.

Source: Arduino UNO Q rescue image (unoq-bootloader-emmc-linux-251020.zip)
URL: https://downloads.arduino.cc/debian-im/
License: Arduino/Qualcomm Proprietary
Purpose: Enables EDL mode flashing for Arduino UNO Q

The firehose programmer is installed to $(HOST_DIR)/share/qdl/ by the host-qdl
package and automatically included in the deployment package by post-image.sh.
This binary cannot be built from source as it requires OEM signing by Qualcomm.

Note: Arduino's rescue image is derived from Linaro's RB1 rescue image and
contains the same firehose programmer binary.

Device Tree Overlays
====================

This configuration builds device tree overlays for Arduino UNO Q accessories:

- qrb2210-arduino-imola-gigadisplay.dtbo: Support for Arduino GigaDisplay
- qrb2210-arduino-imola-camera-rpiv2.dtbo: Support for Raspberry Pi Camera v2
- qrb2210-arduino-imola-odd.dtbo: Support for ODD carrier board

The overlays are included in the EFI partition and can be loaded by U-Boot or
applied at runtime using standard Linux overlay mechanisms.

Customisation
=============

Boot Script
-----------

The boot script (board/arduino/arduino-uno-q/boot.cmd) can be customised to:
- Change kernel command line parameters
- Load device tree overlays
- Configure boot order
- Set environment variables

After modifying boot.cmd, rebuild to regenerate boot.scr:

    $ make

U-Boot Configuration
--------------------

U-Boot configuration fragments are in board/arduino/arduino-uno-q/uboot.config.
This includes settings for:
- Device tree selection (qrb2210-arduino-imola)
- Boot command (loads boot.scr from EFI partition)
- USB, MMC, and fastboot support
- Console and boot delay settings

After modifying uboot.config, rebuild U-Boot:

    $ make uboot-dirclean
    $ make

Kernel Configuration
--------------------

The kernel uses Arduino's default defconfig. To customise:

    $ make linux-menuconfig
    $ make linux-update-defconfig

This will update configs/arduino_uno_q_defconfig with your changes.

Known Limitations
=================

1. U-Boot environment storage: The current configuration stores U-Boot environment
   variables in eMMC at offset 0x400000. This may conflict with other partitions
   if the partition layout changes. The "bad CRC" warning during boot is normal
   for first boot and can be ignored.

2. EFI boot variables: U-Boot displays "Failed to load EFI variables" which is
   expected as the uefivarstore partition is not configured. This does not affect
   the boot process.

3. Network support: The configuration includes network drivers but "No ethernet found"
   is displayed during boot. Network functionality requires additional hardware
   configuration and drivers.

References
==========

- Arduino UNO Q: https://docs.arduino.cc/hardware/uno-q/
- Arduino Linux kernel: https://github.com/arduino/linux-qcom (branch: qcom-v6.16.7-unoq)
- Arduino U-Boot: https://github.com/arduino/u-boot (branch: qcom-mainline)
- Qualcomm QCM2290: https://www.qualcomm.com/products/internet-of-things/industrial/building-enterprise/qcm2290
- Buildroot manual: https://buildroot.org/downloads/manual/manual.html
- qdl (Qualcomm Download Tool): https://github.com/linux-qdl/qdl
