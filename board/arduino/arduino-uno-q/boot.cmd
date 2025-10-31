# U-Boot boot script for Arduino UNO Q
# This script loads the kernel and device tree from the EFI partition (part 67)
# and boots with the rootfs partition (part 68) as root

echo "Arduino UNO Q - Booting Buildroot Linux..."

# Set the MMC device (eMMC)
setenv mmc_dev 0

# Partition numbers from the GPT layout (in hex for U-Boot)
# efi partition = 67 decimal = 0x43 hex
# rootfs partition = 68 decimal = 0x44 hex
setenv efi_part 0x43
setenv rootfs_part 0x44

echo "Loading kernel from mmc ${mmc_dev}:${efi_part}..."

# Load kernel image
if load mmc ${mmc_dev}:${efi_part} ${kernel_addr_r} Image; then
    echo "Kernel loaded successfully"
else
    echo "ERROR: Failed to load kernel"
    exit
fi

# Load device tree
echo "Loading device tree..."
if load mmc ${mmc_dev}:${efi_part} ${fdt_addr_r} qrb2210-arduino-imola.dtb; then
    echo "Device tree loaded successfully"
else
    echo "ERROR: Failed to load device tree"
    exit
fi

# Set kernel command line (rootfs is partition 68)
setenv bootargs "console=ttyMSM0,115200 root=/dev/mmcblk0p68 rootwait rw earlycon"

echo "Booting kernel..."
echo "bootargs: ${bootargs}"

# Boot the kernel
booti ${kernel_addr_r} - ${fdt_addr_r}

# If we get here, boot failed
echo "ERROR: Kernel boot failed!"
