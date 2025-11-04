################################################################################
#
# arduino-router
#
################################################################################

ARDUINO_ROUTER_VERSION = 0.6.2
ARDUINO_ROUTER_SITE = $(call github,arduino,arduino-router,v$(ARDUINO_ROUTER_VERSION))
ARDUINO_ROUTER_LICENSE = GPL-3.0
ARDUINO_ROUTER_LICENSE_FILES = main.go

ARDUINO_ROUTER_GOMOD = github.com/arduino/arduino-router

ARDUINO_ROUTER_LDFLAGS = \
	-X main.Version=$(ARDUINO_ROUTER_VERSION)

ARDUINO_ROUTER_DEPENDENCIES = socat libgpiod

define ARDUINO_ROUTER_INSTALL_INIT_SYSTEMD
	$(INSTALL) -D -m 0644 $(ARDUINO_ROUTER_PKGDIR)/arduino-router.service \
		$(TARGET_DIR)/usr/lib/systemd/system/arduino-router.service
	$(INSTALL) -D -m 0644 $(ARDUINO_ROUTER_PKGDIR)/arduino-router-serial.service \
		$(TARGET_DIR)/usr/lib/systemd/system/arduino-router-serial.service
endef

$(eval $(golang-package))
