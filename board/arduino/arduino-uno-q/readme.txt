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
- Linaro's U-Boot for Qualcomm (v2025.04) from: https://git.codelinaro.org/linaro/qcomlt/u-boot

The board uses Qualcomm's proprietary bootloader chain (XBL, TZ, ABL) with U-Boot
chainloaded after ABL. This provides USB Mass Storage mode for easy deployment with
tools like fwup (Nerves) or dd.

How to build
============

    $ make arduino_uno_q_defconfig
    $ make

Note: You will need access to the internet to download the required sources,
including the Arduino kernel from GitHub.

Files created in output directory
==================================

output/images/

├── boot.img                                    (U-Boot packaged as Android boot image)
├── u-boot.bin                                  (U-Boot bootloader binary)
├── Image                                       (Linux kernel)
├── qrb2210-arduino-imola.dtb                  (Base board device tree)
├── qrb2210-arduino-imola-gigadisplay.dtbo     (GigaDisplay overlay)
├── qrb2210-arduino-imola-camera-rpiv2.dtbo    (RPi Camera v2 overlay)
├── qrb2210-arduino-imola-odd.dtbo             (ODD carrier overlay)
├── rootfs.ext2                                 (Root filesystem)
├── rootfs.ext4 -> rootfs.ext2
└── deploy/                                     (All files needed for deployment)

Boot Architecture
=================

The Arduino UNO Q uses a U-Boot chainloading architecture:

    Power On → XBL (Primary Boot) → TZ (TrustZone) → ABL (Android Boot Loader)
             → U-Boot (chainloaded) → Linux Kernel

U-Boot is packaged as an Android boot image (boot.img) which ABL loads thinking
it's a Linux kernel. Once U-Boot is running, it provides:
- USB Mass Storage mode (exposes eMMC as /dev/sdX on host)
- Fastboot protocol
- Standard boot options (eMMC, USB, network)

This architecture enables easy deployment with tools like fwup (Nerves) or dd.

Creating boot.img
=================

U-Boot must be packaged as an Android boot image for ABL to chainload it.
This is done automatically during the build process using abootimg.

The build system:
1. Compiles U-Boot to u-boot.bin
2. Creates an empty ramdisk (required by Android boot image format)
3. Uses abootimg to package u-boot.bin as boot.img with the configuration
   from board/arduino/arduino-uno-q/bootimg.cfg

After the build completes, boot.img will be ready in:
- output/images/boot.img
- output/images/deploy/boot.img

No manual steps are required. The boot image parameters are:
- pagesize: 4096 (0x1000)
- kerneladdr: 0x80008000
- ramdiskaddr: 0x82000000
- tagsaddr: 0x81e00000

Initial U-Boot Installation
============================

First, flash U-Boot to the board's boot partition. You only need to do this once.

Method 1: Using Fastboot (if board has fastboot in bootloader)
---------------------------------------------------------------

1. Connect board to host via USB
2. Boot board into fastboot mode (consult Arduino documentation)
3. Flash U-Boot:

    $ fastboot flash boot output/images/boot.img
    $ fastboot reboot

Method 2: Using EDL Mode with qdl (Emergency Download)
-------------------------------------------------------

If fastboot isn't available, use Qualcomm EDL (Emergency Download) mode:

1. Install qdl tool on host:

    $ git clone https://github.com/linux-qdl/qdl.git
    $ cd qdl && make && sudo make install

2. Boot board into EDL mode (usually a specific button combination)

3. Flash U-Boot to boot partition:

    $ qdl --storage emmc boot output/images/deploy/boot.img

Method 3: Using Arduino's Official Flashing Tools
--------------------------------------------------

Consult Arduino's documentation for their official flashing procedure.
You'll need to replace the boot partition contents with output/images/deploy/boot.img

Deploying Images with USB Mass Storage Mode (Recommended for Nerves/fwup)
==========================================================================

Once U-Boot is installed, you can easily deploy operating system images:

1. Power on the board and interrupt U-Boot boot (press SPACE when prompted)

2. In U-Boot console, enable USB Mass Storage mode:

    => ums 0 mmc 0

3. The board's eMMC will appear as /dev/sdX on your host computer

4. Deploy your image using fwup (Nerves) or dd:

    # For Nerves with fwup:
    $ fwup your-nerves-image.fw

    # Or with dd:
    $ sudo dd if=your-image.img of=/dev/sdX bs=1M status=progress
    $ sync

5. Unplug USB cable or press Ctrl+C in U-Boot console to exit UMS mode

6. Reboot the board:

    => reset

The board will boot into your newly flashed system.

Serial Console
==============

The serial console is available on UART4 (ttyMSM0) at 115200 baud, 8N1.
Check Arduino's documentation for the physical location of the serial pins
or USB-to-serial adapter information.

U-Boot and Linux both output to this console, which is useful for:
- Interrupting U-Boot boot sequence
- Debugging boot issues
- Accessing U-Boot console for USB Mass Storage mode

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

Device Tree Overlays
====================

This configuration builds device tree overlays for Arduino UNO Q accessories:

- qrb2210-arduino-imola-gigadisplay.dtbo: Support for Arduino GigaDisplay
- qrb2210-arduino-imola-camera-rpiv2.dtbo: Support for Raspberry Pi Camera v2
- qrb2210-arduino-imola-odd.dtbo: Support for ODD carrier board

U-Boot supports applying overlays at boot time using the 'fdt' commands.
Alternatively, overlays can be applied by the kernel or userspace tools.

Nerves Integration
==================

This Buildroot configuration is designed to work with Nerves (Elixir embedded framework).

The U-Boot USB Mass Storage mode enables easy Nerves deployment:

1. Build your Nerves firmware as usual
2. Boot Arduino UNO Q into U-Boot USB Mass Storage mode (ums 0 mmc 0)
3. Use fwup to deploy: fwup your-app.fw
4. Reboot

The fwup configuration for Nerves should target /dev/mmcblk0 with appropriate
partitioning for A/B updates. Consider this partition layout:

  /dev/mmcblk0p1  - boot (contains U-Boot boot.img)     ~10MB
  /dev/mmcblk0p2  - nerves-a (Nerves system A)          ~500MB
  /dev/mmcblk0p3  - nerves-b (Nerves system B)          ~500MB
  /dev/mmcblk0p4  - data (application data partition)   ~remaining

U-Boot can be configured to boot from either nerves-a or nerves-b partitions
for atomic A/B updates.

Known Limitations
=================

As of 2025-10-28:

1. This configuration uses Linaro's Qualcomm U-Boot fork. Support for QCM2290
   is not yet in mainline U-Boot (though other Qualcomm platforms are).
   Monitor upstream for when QCM2290 support is merged.

2. U-Boot configuration (uboot.config) includes USB Mass Storage support but
   requires hardware validation to confirm all features work correctly on
   Arduino UNO Q hardware.

3. The U-Boot defconfig used (qcom_defconfig) may need board-specific
   customisation. Check Linaro's repository for Arduino UNO Q-specific configs
   or RB1/RB2 configs (similar eMMC-based boards).

4. Initial U-Boot installation requires either fastboot, EDL mode, or Arduino's
   official flashing tools. Consult Arduino documentation for board-specific
   procedures.

5. This configuration builds successfully but requires hardware testing to
   validate the complete boot chain and USB Mass Storage functionality.

References
==========

- Arduino UNO Q: https://docs.arduino.cc/hardware/uno-q/
- Arduino Linux kernel: https://github.com/arduino/linux-qcom
- Linaro U-Boot for Qualcomm: https://git.codelinaro.org/linaro/qcomlt/u-boot
- Linaro U-Boot announcement: https://www.linaro.org/blog/initial-u-boot-release-for-qualcomm-platforms/
- Qualcomm QCM2290: https://www.qualcomm.com/products/internet-of-things/industrial/building-enterprise/qcm2290
- Buildroot manual: https://buildroot.org/downloads/manual/manual.html
- Nerves Project: https://nerves-project.org/
- fwup firmware update tool: https://github.com/fwup-home/fwup
- qdl (Qualcomm Download Tool): https://github.com/linux-qdl/qdl
