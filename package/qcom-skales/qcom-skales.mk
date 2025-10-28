################################################################################
#
# qcom-skales
#
################################################################################

QCOM_SKALES_VERSION = 1ccd3e924f6955b1c9d5f921e5311c8db8411787
QCOM_SKALES_SITE = https://git.codelinaro.org/clo/qsdk/oss/tools/skales.git
QCOM_SKALES_SITE_METHOD = git
QCOM_SKALES_LICENSE = BSD-3-Clause
QCOM_SKALES_LICENSE_FILES = LICENSE

# Host-only package for creating boot images
HOST_QCOM_SKALES_DEPENDENCIES = host-python3

define HOST_QCOM_SKALES_INSTALL_CMDS
	$(INSTALL) -D -m 0755 $(@D)/mkbootimg $(HOST_DIR)/bin/mkbootimg-qcom
	$(INSTALL) -D -m 0755 $(@D)/dtbTool $(HOST_DIR)/bin/dtbTool
endef

$(eval $(host-generic-package))
