#!/bin/bash
#
# Arduino UNO Q Flash Script
#
# This script flashes a complete Buildroot system to the Arduino UNO Q board
# using Qualcomm's qdl (Qualcomm Download) tool via EDL mode.
#
# Requirements:
#   - qdl tool installed (https://github.com/linux-qdl/qdl)
#   - Board in EDL mode (hold button during power-on)
#   - Root/sudo access
#
# Usage:
#   sudo ./flash.sh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLASH_DIR="${SCRIPT_DIR}/flash"

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No colour

echo "======================================================================="
echo "Arduino UNO Q - Buildroot Flash Script"
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
REQUIRED_FILES=(
    "prog_firehose_ddr.elf"
    "boot.img"
    "efi.img"
    "rootfs.img"
)

echo "Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "${FLASH_DIR}/${file}" ]; then
        echo -e "${RED}ERROR: Required file missing: ${file}${NC}"
        exit 1
    fi
    echo -e "  ${GREEN}✓${NC} ${file}"
done
echo ""

# Show file sizes
echo "Image sizes:"
echo "  boot.img:   $(du -h "${FLASH_DIR}/boot.img" | cut -f1)"
echo "  efi.img:    $(du -h "${FLASH_DIR}/efi.img" | cut -f1)"
echo "  rootfs.img: $(du -h "${FLASH_DIR}/rootfs.img" | cut -f1)"
echo ""

# Warning
echo -e "${YELLOW}WARNING: This will overwrite the boot_a, efi and rootfs partitions!${NC}"
echo "         Boot chain: UEFI → ABL → boot.img (U-Boot) → kernel"
echo "         Other bootloader partitions (xbl, tz, rpm, etc.) will NOT be modified."
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

cd "${FLASH_DIR}"

if ${QDL_BIN} --storage emmc prog_firehose_ddr.elf ../rawprogram_buildroot.xml; then
    echo ""
    echo -e "${GREEN}=======================================================================${NC}"
    echo -e "${GREEN}Flash completed successfully!${NC}"
    echo -e "${GREEN}=======================================================================${NC}"
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
    echo "  - Board is in EDL mode (hold button during power-on)"
    echo "  - USB cable is connected"
    echo "  - qdl has permissions to access USB devices"
    exit 1
fi
