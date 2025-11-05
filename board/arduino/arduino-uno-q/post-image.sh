#!/bin/bash
set -e

BOARD_DIR="$(dirname "$0")"
IMAGES_DIR="${BINARIES_DIR:-output/images}"
BUILD_DIR="${BUILD_DIR:-output/build}"

echo "Arduino UNO Q: Post-build processing"
echo ""

# Create Android boot image with U-Boot
echo "Creating Android boot image with mkbootimg..."
if [ ! -f "${IMAGES_DIR}/u-boot.bin" ]; then
    echo "ERROR: u-boot.bin not found"
    exit 1
fi

# Create kernel for boot.img: gzip(U-Boot) + raw DTB appended
# ABL scans the compressed data for DTB magic, so DTB must be appended AFTER gzipping
# This matches Arduino's boot.img structure:
#   - gzipped U-Boot: decompressible on its own
#   - raw DTB: appended to gzipped data, NOT inside the gzip stream
cp "${IMAGES_DIR}/u-boot.bin" "${IMAGES_DIR}/u-boot-nodtb.bin"
gzip -n -c "${IMAGES_DIR}/u-boot-nodtb.bin" > "${IMAGES_DIR}/u-boot.bin.gz"
cat "${IMAGES_DIR}/u-boot.bin.gz" "${IMAGES_DIR}/qrb2210-arduino-imola.dtb" > "${IMAGES_DIR}/u-boot-gz-dtb"

# Create empty ramdisk file (Qualcomm's mkbootimg requires a ramdisk parameter)
touch "${IMAGES_DIR}/empty-ramdisk"

# Use Qualcomm's skales mkbootimg
# Parameters based on meta-qcom linux-qcom-bootimg.bbclass and u-boot_%.bbappend
# - kernel: gzipped U-Boot + raw DTB appended (ABL scans for DTB magic in compressed data)
# - ramdisk: empty file (required by skales mkbootimg)
# - cmdline: dummy value matching Arduino (root=/dev/notreal)
# - base: 0x80000000 (Qualcomm standard base address)
# - pagesize: 4096 (standard)
"${HOST_DIR}/bin/mkbootimg-qcom" \
    --kernel "${IMAGES_DIR}/u-boot-gz-dtb" \
    --ramdisk "${IMAGES_DIR}/empty-ramdisk" \
    --cmdline "root=/dev/notreal" \
    --base 0x80000000 \
    --pagesize 4096 \
    --output "${IMAGES_DIR}/boot.img"

if [ -f "${IMAGES_DIR}/boot.img" ]; then
    echo "✓ Created boot.img with mkbootimg"
else
    echo "ERROR: Failed to create boot.img"
    exit 1
fi

# Compile U-Boot boot script
echo "Compiling U-Boot boot script..."
"${HOST_DIR}/bin/mkimage" -C none -A arm64 -T script -d "${BOARD_DIR}/boot.cmd" "${IMAGES_DIR}/boot.scr"

# Create EFI partition with genimage
echo "Creating EFI partition (FAT32) with kernel and device trees..."
support/scripts/genimage.sh -c "${BOARD_DIR}/genimage-efi.cfg"

if [ $? -eq 0 ]; then
    echo "✓ Created efi.vfat successfully"
else
    echo "✗ Failed to create EFI partition"
    exit 1
fi

# Create a deployment package with all necessary files
echo ""
echo "Creating deployment package..."
mkdir -p "${IMAGES_DIR}/deploy/flash"

# Copy Arduino UNO Q firmware files for flashing (provided by host-arduino-uno-q-firmware package)
FIRMWARE_DIR="${HOST_DIR}/share/arduino-uno-q-firmware"

# Copy EDL programmer and bootloader files
cp "${FIRMWARE_DIR}/prog_firehose_ddr.elf" "${IMAGES_DIR}/deploy/flash/"
cp "${FIRMWARE_DIR}"/*.elf "${IMAGES_DIR}/deploy/flash/"
cp "${FIRMWARE_DIR}"/*.mbn "${IMAGES_DIR}/deploy/flash/"
cp "${FIRMWARE_DIR}"/gpt_*.bin "${IMAGES_DIR}/deploy/flash/"
cp "${FIRMWARE_DIR}"/zeros_*.bin "${IMAGES_DIR}/deploy/flash/"
cp "${FIRMWARE_DIR}/rawprogram0.xml" "${IMAGES_DIR}/deploy/"
cp "${FIRMWARE_DIR}/patch0.xml" "${IMAGES_DIR}/deploy/"

# Copy our built images
cp "${IMAGES_DIR}/boot.img" "${IMAGES_DIR}/deploy/flash/"
cp "${IMAGES_DIR}/efi.vfat" "${IMAGES_DIR}/deploy/flash/efi.img"
cp "${IMAGES_DIR}/rootfs.ext4" "${IMAGES_DIR}/deploy/flash/rootfs.img"

# Copy deployment script and partition layouts
cp "${BOARD_DIR}/flash.sh" "${IMAGES_DIR}/deploy/"
cp "${BOARD_DIR}/rawprogram_buildroot.xml" "${IMAGES_DIR}/deploy/"
cp "${BOARD_DIR}/rawprogram_complete.xml" "${IMAGES_DIR}/deploy/"

echo ""
echo "==================================================================="
echo "Arduino UNO Q Build Complete!"
echo "==================================================================="
echo ""
echo "Deployment files are in: ${IMAGES_DIR}/deploy/"
echo ""
echo "To flash the system:"
echo "  1. Boot board into EDL mode (USB_BOOT pin to GND in JCTL header)"
echo ""
echo "  2. Quick flash (boot, efi, rootfs only - requires existing bootloaders):"
echo "     cd ${IMAGES_DIR}/deploy && sudo ./flash.sh"
echo ""
echo "  3. Complete flash (all bootloaders + images - for initial flash or recovery):"
echo "     cd ${IMAGES_DIR}/deploy && sudo ./flash.sh --complete"
echo ""
echo "Quick flash writes:"
echo "  - boot.img (Android boot image with U-Boot + device tree)"
echo "  - efi.img (kernel + device trees for U-Boot to load)"
echo "  - rootfs.img (Buildroot filesystem)"
echo ""
echo "Complete flash additionally writes:"
echo "  - GPT partition tables"
echo "  - All bootloaders (xbl, tz, rpm, hyp, abl, etc.)"
echo "  - All firmware (km4, imagefv, uefi_sec, devcfg, etc.)"
echo ""
echo "Boot chain: UEFI → ABL → boot.img (U-Boot) → kernel"
echo ""
echo "==================================================================="
