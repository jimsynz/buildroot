################################################################################
#
# arduino-uno-q-firmware
#
################################################################################

ARDUINO_UNO_Q_FIRMWARE_VERSION = 251020
ARDUINO_UNO_Q_FIRMWARE_SITE = https://downloads.arduino.cc/debian-im
ARDUINO_UNO_Q_FIRMWARE_SOURCE = unoq-bootloader-emmc-linux-$(ARDUINO_UNO_Q_FIRMWARE_VERSION).zip
ARDUINO_UNO_Q_FIRMWARE_LICENSE = Arduino/Qualcomm Proprietary
ARDUINO_UNO_Q_FIRMWARE_LICENSE_FILES = LICENSE
ARDUINO_UNO_Q_FIRMWARE_INSTALL_TARGET = NO

# Bootloader and firmware files to extract from the rescue image
ARDUINO_UNO_Q_FIRMWARE_FILES = \
	prog_firehose_ddr.elf \
	xbl.elf \
	xbl_feature_config.elf \
	tz.mbn \
	rpm.mbn \
	hyp.mbn \
	abl.elf \
	km4.mbn \
	imagefv.elf \
	uefi_sec.mbn \
	devcfg.mbn \
	featenabler.mbn \
	qupv3fw.elf \
	storsec.mbn \
	multi_image.mbn \
	rawprogram0.xml \
	patch0.xml \
	gpt_main0.bin \
	gpt_backup0.bin \
	zeros_1sector.bin \
	zeros_33sectors.bin \
	LICENSE

define HOST_ARDUINO_UNO_Q_FIRMWARE_EXTRACT_CMDS
	$(UNZIP) -d $(@D) $($(PKG)_DL_DIR)/$(ARDUINO_UNO_Q_FIRMWARE_SOURCE)
	mv $(@D)/unoq-bootloader-emmc-linux-$(ARDUINO_UNO_Q_FIRMWARE_VERSION)/* $(@D)/
	rmdir $(@D)/unoq-bootloader-emmc-linux-$(ARDUINO_UNO_Q_FIRMWARE_VERSION)
endef

define HOST_ARDUINO_UNO_Q_FIRMWARE_INSTALL_CMDS
	mkdir -p $(HOST_DIR)/share/arduino-uno-q-firmware
	$(foreach f,$(ARDUINO_UNO_Q_FIRMWARE_FILES), \
		$(INSTALL) -D -m 0644 $(@D)/$(f) \
			$(HOST_DIR)/share/arduino-uno-q-firmware/$(f)$(sep))
endef

$(eval $(host-generic-package))
