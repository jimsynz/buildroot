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

# Qualcomm EDL firehose programmer from Linaro RB1 rescue image
# This OEM-signed programmer is required for QCM2290-based boards
QDL_LINARO_VERSION = 47528
QDL_LINARO_SITE = https://releases.linaro.org/96boards/rb1/linaro/rescue/23.12
QDL_LINARO_SOURCE = rb1-bootloader-emmc-linux-$(QDL_LINARO_VERSION).zip
QDL_LINARO_FILE = $(BR2_DL_DIR)/qdl/$(QDL_LINARO_SOURCE)

# Download the Linaro RB1 bootloader package containing the firehose programmer
define HOST_QDL_DOWNLOAD_FIREHOSE
	test -f $(QDL_LINARO_FILE) || \
		(mkdir -p $(BR2_DL_DIR)/qdl && \
		wget -O $(QDL_LINARO_FILE) $(QDL_LINARO_SITE)/$(QDL_LINARO_SOURCE))
endef

HOST_QDL_PRE_EXTRACT_HOOKS += HOST_QDL_DOWNLOAD_FIREHOSE

# Extract firehose programmer and LICENSE from the downloaded Linaro package
define HOST_QDL_EXTRACT_FIREHOSE
	$(UNZIP) -j $(QDL_LINARO_FILE) \
		rb1-bootloader-emmc-linux-$(QDL_LINARO_VERSION)/prog_firehose_ddr.elf \
		rb1-bootloader-emmc-linux-$(QDL_LINARO_VERSION)/LICENSE \
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
		$(HOST_DIR)/share/qdl/LICENSE.linaro
endef

$(eval $(host-generic-package))
