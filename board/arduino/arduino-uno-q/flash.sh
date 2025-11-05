#!/bin/bash
#
# Arduino UNO Q Flash Script
#
# This script flashes a Buildroot system to the Arduino UNO Q board
# using Qualcomm's qdl (Qualcomm Download) tool via EDL mode.
#
# Requirements:
#   - qdl tool installed (https://github.com/linux-qdl/qdl)
#   - Board in EDL mode (USB_BOOT pin connected to GND in JCTL header)
#   - Root/sudo access
#
# Usage:
#   sudo ./flash.sh           # Quick mode: flash boot, efi, rootfs only
#   sudo ./flash.sh --complete  # Complete mode: flash all bootloaders + images
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLASH_DIR="${SCRIPT_DIR}/flash"
COMPLETE_FLASH=false

# Parse arguments
if [ "$1" = "--complete" ]; then
    COMPLETE_FLASH=true
fi

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No colour

echo "======================================================================="
echo "Arduino UNO Q - Buildroot Flash Script"
if [ "$COMPLETE_FLASH" = true ]; then
    echo "Mode: COMPLETE (all bootloaders + images)"
else
    echo "Mode: QUICK (boot, efi, rootfs only)"
fi
echo "======================================================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}ERROR: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Check if qdl is available (prefer Buildroot's version)
QDL_BIN=""
BUILDROOT_QDL="${SCRIPT_DIR}/../../host/bin/qdl"
if [ -x "${BUILDROOT_QDL}" ]; then
    QDL_BIN="$(readlink -f "${BUILDROOT_QDL}")"
    echo "Using Buildroot qdl: ${QDL_BIN}"
elif command -v qdl &> /dev/null; then
    QDL_BIN="qdl"
    echo "Using system qdl: $(which qdl)"
else
    echo -e "${RED}ERROR: qdl tool not found${NC}"
    echo ""
    echo "qdl should have been built by Buildroot (output/host/bin/qdl)"
    echo "If missing, check that BR2_PACKAGE_HOST_QDL=y in your defconfig"
    exit 1
fi
echo ""

# Check if flash directory exists
if [ ! -d "${FLASH_DIR}" ]; then
    echo -e "${RED}ERROR: Flash directory not found: ${FLASH_DIR}${NC}"
    exit 1
fi

# Check required files
if [ "$COMPLETE_FLASH" = true ]; then
    REQUIRED_FILES=(
        "prog_firehose_ddr.elf"
        "xbl.elf"
        "xbl_feature_config.elf"
        "tz.mbn"
        "rpm.mbn"
        "hyp.mbn"
        "abl.elf"
        "km4.mbn"
        "imagefv.elf"
        "uefi_sec.mbn"
        "devcfg.mbn"
        "featenabler.mbn"
        "qupv3fw.elf"
        "storsec.mbn"
        "multi_image.mbn"
        "gpt_main0.bin"
        "gpt_backup0.bin"
        "zeros_33sectors.bin"
        "boot.img"
        "efi.img"
        "rootfs.img"
    )
    RAWPROGRAM="${SCRIPT_DIR}/rawprogram_complete.xml"
    PATCHFILE="${SCRIPT_DIR}/patch0.xml"
else
    REQUIRED_FILES=(
        "prog_firehose_ddr.elf"
        "boot.img"
        "efi.img"
        "rootfs.img"
    )
    RAWPROGRAM="${SCRIPT_DIR}/rawprogram_buildroot.xml"
    PATCHFILE=""
fi

echo "Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${FLASH_DIR}/${file}" ]; then
        echo -e "${RED}ERROR: Required file missing: ${file}${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} ${file}"
done

# Check rawprogram file
if [ ! -f "${RAWPROGRAM}" ]; then
    echo -e "${RED}ERROR: Rawprogram file not found: ${RAWPROGRAM}${NC}"
    exit 1
fi
echo -e "  ${GREEN}✓${NC} $(basename "${RAWPROGRAM}")"

# Check patch file if needed
if [ -n "${PATCHFILE}" ] && [ ! -f "${PATCHFILE}" ]; then
    echo -e "${RED}ERROR: Patch file not found: ${PATCHFILE}${NC}"
    exit 1
fi
if [ -n "${PATCHFILE}" ]; then
    echo -e "  ${GREEN}✓${NC} $(basename "${PATCHFILE}")"
fi
echo ""

# Show file sizes
echo "Image sizes:"
echo "  boot.img:   $(du -h "${FLASH_DIR}/boot.img" | cut -f1)"
echo "  efi.img:    $(du -h "${FLASH_DIR}/efi.img" | cut -f1)"
echo "  rootfs.img: $(du -h "${FLASH_DIR}/rootfs.img" | cut -f1)"
echo ""

# Warning
if [ "$COMPLETE_FLASH" = true ]; then
    echo -e "${YELLOW}WARNING: COMPLETE FLASH MODE${NC}"
    echo -e "${YELLOW}This will COMPLETELY REFLASH the device including:${NC}"
    echo "  - GPT partition tables"
    echo "  - All bootloaders (XBL, TrustZone, RPM, Hypervisor, ABL, etc.)"
    echo "  - All firmware (Keymaster, UEFI components, device config, etc.)"
    echo "  - Boot images (boot_a, boot_b with U-Boot)"
    echo "  - EFI partition (kernel + device trees)"
    echo "  - Rootfs partition (Buildroot filesystem)"
    echo ""
    echo "Boot chain: UEFI → ABL → boot.img (U-Boot) → kernel"
    echo ""
    echo -e "${RED}This is a DESTRUCTIVE operation. Only use for initial flashing or recovery.${NC}"
else
    echo -e "${YELLOW}WARNING: QUICK FLASH MODE${NC}"
    echo "This will overwrite the following partitions:"
    echo "  - boot_a (Android boot image with U-Boot)"
    echo "  - efi (kernel + device trees)"
    echo "  - rootfs (Buildroot filesystem)"
    echo ""
    echo "Boot chain: UEFI → ABL → boot.img (U-Boot) → kernel"
    echo ""
    echo "Bootloader partitions (xbl, tz, rpm, etc.) will NOT be modified."
    echo "They must already be present on the device (from Arduino factory image)."
fi
echo ""
read -p "Continue? (yes/no) " -r
echo
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Flash with qdl
echo "Flashing Arduino UNO Q..."
echo "Waiting for board in EDL mode..."
echo ""
echo "To enter EDL mode: Connect USB_BOOT pin to GND in the JCTL header,"
echo "                   then power on the board."
echo ""

cd "${FLASH_DIR}"

# Build qdl command
QDL_CMD="${QDL_BIN} --storage emmc prog_firehose_ddr.elf ${RAWPROGRAM}"
if [ -n "${PATCHFILE}" ]; then
    QDL_CMD="${QDL_CMD} ${PATCHFILE}"
fi

if ${QDL_CMD}; then
    echo ""
    echo -e "${GREEN}=======================================================================${NC}"
    echo -e "${GREEN}Flash completed successfully!${NC}"
    echo -e "${GREEN}=======================================================================${NC}"
    echo ""
    if [ "$COMPLETE_FLASH" = true ]; then
        echo "Complete system has been flashed including all bootloaders."
    else
        echo "Boot, EFI, and rootfs partitions have been updated."
    fi
    echo ""
    echo "The board will reboot automatically."
    echo "Serial console: UART4 (ttyMSM0) at 115200 baud"
    echo ""
else
    echo ""
    echo -e "${RED}=======================================================================${NC}"
    echo -e "${RED}Flash failed!${NC}"
    echo -e "${RED}=======================================================================${NC}"
    echo ""
    echo "Please check:"
    echo "  - Board is in EDL mode (USB_BOOT pin connected to GND in JCTL header)"
    echo "  - USB cable is connected"
    echo "  - qdl has permissions to access USB devices"
    exit 1
fi
