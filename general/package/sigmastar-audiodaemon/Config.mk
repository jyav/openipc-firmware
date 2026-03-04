################################################################################
# sigmastar-audiodaemon
################################################################################

SIGMASTAR_AUDIODAEMON_VERSION = master
SIGMASTAR_AUDIODAEMON_SITE = $(call github,jyav,sigmastar-audiodaemon,$(SIGMASTAR_AUDIODAEMON_VERSION))
SIGMASTAR_AUDIODAEMON_LICENSE = MIT

# CRITICAL: This forces the SDK headers to be extracted to STAGING_DIR first.
# Note: Check the exact name of the OSDRV package for your chip in the OpenIPC tree.
SIGMASTAR_AUDIODAEMON_DEPENDENCIES = sigmastar-osdrv-infinity6c cjson

# Buildroot passes TARGET_CONFIGURE_OPTS, which automatically injects the correct 
# cross-compiler (CC) and sets the sysroot to point to the staging directory.
define SIGMASTAR_AUDIODAEMON_BUILD_CMDS
    $(MAKE) $(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(TARGET_CFLAGS) -I$(STAGING_DIR)/usr/include -I$(STAGING_DIR)/usr/include/sigmastar" \
		-C $(@D)
endef

define SIGMASTAR_AUDIODAEMON_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/iad $(TARGET_DIR)/usr/bin/iad
    $(INSTALL) -D -m 0755 $(@D)/iac $(TARGET_DIR)/usr/bin/iac
    $(INSTALL) -D -m 0644 $(@D)/config/iad.json $(TARGET_DIR)/etc/iad.json
endef

$(eval $(generic-package))
