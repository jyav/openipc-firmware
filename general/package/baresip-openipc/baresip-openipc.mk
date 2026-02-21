#############################################################
#
# baresip-openipc
#
#############################################################

BARESIP_OPENIPC_SITE = $(call github,baresip,baresip,$(BARESIP_OPENIPC_VERSION))
BARESIP_OPENIPC_VERSION = v3.14.0

# --- Custom Module Injection ---
define BARESIP_OPENIPC_INJECT_AUPIPE
	mkdir -p $(@D)/app_modules/aupipe
	cp $(BARESIP_OPENIPC_PKGDIR)/files/aupipe.c $(@D)/app_modules/aupipe/
	
	# Generate an official external CMake module target
	echo 'add_library(aupipe MODULE aupipe.c)' > $(@D)/app_modules/aupipe/CMakeLists.txt
	echo 'target_include_directories(aupipe PRIVATE $${CMAKE_SOURCE_DIR}/include)' >> $(@D)/app_modules/aupipe/CMakeLists.txt
	echo 'install(TARGETS aupipe DESTINATION lib/baresip/modules)' >> $(@D)/app_modules/aupipe/CMakeLists.txt
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
    -DAPP_MODULES_DIR=app_modules \
    -DAPP_MODULES="aupipe"

define BARESIP_OPENIPC_INSTALL_CONF
	$(INSTALL) -m 755 -d $(TARGET_DIR)/etc/init.d
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(BARESIP_OPENIPC_PKGDIR)/files/S97baresip

  # Add this line to deploy the audio broker daemon:
	$(INSTALL) -m 755 -t $(TARGET_DIR)/etc/init.d $(BARESIP_OPENIPC_PKGDIR)/files/S98audiopipe

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
