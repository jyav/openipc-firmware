#############################################################
#
# baresip-openipc
#
#############################################################

BARESIP_OPENIPC_SITE = $(call github,baresip,baresip,$(BARESIP_OPENIPC_VERSION))
BARESIP_OPENIPC_VERSION = v3.14.0

# --- Custom Module Injection ---
# Create the module directory, copy our local C file, and append it to Baresip's CMake configuration.
define BARESIP_OPENIPC_INJECT_AUPIPE
	mkdir -p $(@D)/modules/aupipe
	cp $(BARESIP_OPENIPC_PKGDIR)/files/aupipe.c $(@D)/modules/aupipe/
	
	# Create a localized CMakeLists.txt for the module
	echo 'set(MODULE_NAME aupipe)' > $(@D)/modules/aupipe/CMakeLists.txt
	echo 'set(MODULE_SRCS aupipe.c)' >> $(@D)/modules/aupipe/CMakeLists.txt
	echo 'baresip_add_module($${MODULE_NAME} $${MODULE_SRCS})' >> $(@D)/modules/aupipe/CMakeLists.txt
	
	# Instruct Baresip's main module CMakeLists to parse our new folder
	echo 'add_subdirectory(aupipe)' >> $(@D)/modules/CMakeLists.txt
endef

# Hook this injection to run immediately after the 0001 and 0002 patches are applied
BARESIP_OPENIPC_POST_PATCH_HOOKS += BARESIP_OPENIPC_INJECT_AUPIPE

BARESIP_OPENIPC_DEPENDENCIES = libre-openipc mbedtls-openipc webrtc-audio-processing-openipc mosquitto ffmpeg-openipc alsa-lib libv4l

BARESIP_OPENIPC_CONF_OPTS = \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE="-DNDEBUG -s" \
    -DUSE_MBEDTLS=ON \
    -DWEBRTC_AEC_INCLUDE_DIR=$(WEBRTC_AUDIO_PROCESSING_OPENIPC_DIR) \
    -DMOSQUITTO_INCLUDE_DIR=$(MOSQUITTO_DIR) \
    -DMODULE_G711=ON \
    -DMODULE_OPUS=ON \
    -DMODULE_V4L2=ON \
    -DMODULE_ALSA=ON \
    -DMODULE_AVFORMAT=ON \
    -DMODULE_AVCODEC=ON

define BARESIP_OPENIPC_INSTALL_CONF
	$(INSTALL) -m 755 -d $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(BARESIP_OPENIPC_PKGDIR)/files/S97baresip
	$(INSTALL) -m 755 -d $(TARGET_DIR)/etc/baresip
	$(INSTALL) -m 644 -t $(TARGET_DIR)/etc/baresip $(BARESIP_OPENIPC_PKGDIR)/files/accounts
	$(INSTALL) -m 644 -t $(TARGET_DIR)/etc/baresip $(BARESIP_OPENIPC_PKGDIR)/files/config
	$(INSTALL) -m 644 -t $(TARGET_DIR)/etc/baresip $(BARESIP_OPENIPC_PKGDIR)/files/contacts
	$(INSTALL) -m 755 -d $(TARGET_DIR)/usr/bin
	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/bin $(BARESIP_OPENIPC_PKGDIR)/files/dtmf_0.sh
	ln -sf dtmf_0.sh $(TARGET_DIR)/usr/bin/dtmf_1.sh
	ln -sf dtmf_0.sh $(TARGET_DIR)/usr/bin/dtmf_2.sh
	ln -sf dtmf_0.sh $(TARGET_DIR)/usr/bin/dtmf_3.sh
	$(INSTALL) -m 755 -d $(TARGET_DIR)/usr/lib/sounds
#	$(INSTALL) -m 755 -t $(TARGET_DIR)/usr/lib/sounds $(BARESIP_OPENIPC_PKGDIR)/files/ok_8k.pcm
	$(INSTALL) -m 755 -d $(TARGET_DIR)/usr/share/baresip
endef

BARESIP_OPENIPC_POST_INSTALL_TARGET_HOOKS += BARESIP_OPENIPC_INSTALL_CONF

$(eval $(cmake-package))
