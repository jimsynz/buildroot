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

define HOST_QDL_BUILD_CMDS
	$(HOST_MAKE_ENV) $(HOST_CONFIGURE_OPTS) $(MAKE) -C $(@D)
endef

define HOST_QDL_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/qdl $(HOST_DIR)/bin/qdl
endef

$(eval $(host-generic-package))
