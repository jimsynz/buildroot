################################################################################
#
# qdl
#
################################################################################

# Use latest commit from master since there are no release tags
QDL_VERSION = 92b14a1c58efb8c3fb5267aadba1b1c451ea520f
QDL_SITE = $(call github,linux-msm,qdl,$(QDL_VERSION))
QDL_LICENSE = BSD-3-Clause
QDL_LICENSE_FILES = LICENSE

# qdl depends on libxml2 (for XML parsing) and libusb (for USB access)
HOST_QDL_DEPENDENCIES = host-pkgconf host-libxml2 host-libusb

# Qualcomm EDL firehose programmer from Arduino UNO Q rescue image
# This OEM-signed programmer is required for QCM2290-based boards
QDL_ARDUINO_VERSION = 251020
QDL_ARDUINO_SITE = https://downloads.arduino.cc/debian-im
QDL_ARDUINO_SOURCE = unoq-bootloader-emmc-linux-$(QDL_ARDUINO_VERSION).zip
QDL_ARDUINO_FILE = $(BR2_DL_DIR)/qdl/$(QDL_ARDUINO_SOURCE)

# Download the Arduino UNO Q bootloader package containing the firehose programmer
define HOST_QDL_DOWNLOAD_FIREHOSE
	test -f $(QDL_ARDUINO_FILE) || \
		(mkdir -p $(BR2_DL_DIR)/qdl && \
		wget -O $(QDL_ARDUINO_FILE) $(QDL_ARDUINO_SITE)/$(QDL_ARDUINO_SOURCE))
endef

HOST_QDL_PRE_EXTRACT_HOOKS += HOST_QDL_DOWNLOAD_FIREHOSE

# Extract firehose programmer and LICENSE from the downloaded Arduino package
define HOST_QDL_EXTRACT_FIREHOSE
	$(UNZIP) -j $(QDL_ARDUINO_FILE) \
		unoq-bootloader-emmc-linux-$(QDL_ARDUINO_VERSION)/prog_firehose_ddr.elf \
		unoq-bootloader-emmc-linux-$(QDL_ARDUINO_VERSION)/LICENSE \
		-d $(@D)/firehose
endef

HOST_QDL_POST_EXTRACT_HOOKS += HOST_QDL_EXTRACT_FIREHOSE

define HOST_QDL_BUILD_CMDS
	$(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS) $(MAKE) -C $(@D)
endef

define HOST_QDL_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/qdl $(HOST_DIR)/bin/qdl
	$(INSTALL) -D -m 0644 $(@D)/firehose/prog_firehose_ddr.elf \
		$(HOST_DIR)/share/qdl/prog_firehose_ddr.elf
	$(INSTALL) -D -m 0644 $(@D)/firehose/LICENSE \
		$(HOST_DIR)/share/qdl/LICENSE.arduino
endef

$(eval $(host-generic-package))
