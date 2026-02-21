#############################################################
#
# baresip-openipc
#
#############################################################

BARESIP_OPENIPC_SITE = $(call github,baresip,baresip,$(BARESIP_OPENIPC_VERSION))
BARESIP_OPENIPC_VERSION = v3.14.0

# --- Custom Module Injection ---
define BARESIP_OPENIPC_INJECT_AUPIPE
	mkdir -p $(@D)/modules/aupipe
	cp $(BARESIP_OPENIPC_PKGDIR)/files/aupipe.c $(@D)/modules/aupipe/
	
	# Generate a Baresip 3.x compliant CMakeLists for the custom module
	echo 'project(aupipe)' > $(@D)/modules/aupipe/CMakeLists.txt
	echo 'list(APPEND MODULES_DETECTED $${PROJECT_NAME})' >> $(@D)/modules/aupipe/CMakeLists.txt
	echo 'set(MODULES_DETECTED $${MODULES_DETECTED} PARENT_SCOPE)' >> $(@D)/modules/aupipe/CMakeLists.txt
	echo 'add_library($${PROJECT_NAME} MODULE aupipe.c)' >> $(@D)/modules/aupipe/CMakeLists.txt
	echo 'install(TARGETS $${PROJECT_NAME} DESTINATION lib/baresip/modules)' >> $(@D)/modules/aupipe/CMakeLists.txt
	
	# Inject it into the main build loop
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
    -DMOSQUITTO_INCLUDE_DIR=$(MOSQUITTO_DIR)

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
