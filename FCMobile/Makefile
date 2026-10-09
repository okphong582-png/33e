THEOS ?= /home/hoang/theos
ARCHS := arm64
TARGET := iphone:clang:16.5:14.0
FINALPACKAGE := 1
FOR_RELEASE := 1
DEBUG := 0
BUILD_KIND ?= dylib
include $(THEOS)/makefiles/common.mk
ifeq ($(BUILD_KIND),tipa)
APPLICATION_NAME := FCMMenu
PRODUCT := FCMMenu
FCMMenu_FILES := TIPA.mm ui/Overlay.mm core/Process.mm
FCMMenu_RESOURCE_DIRS := Resources
FCMMenu_CODESIGN_FLAGS := -Sentitlements.plist
else ifeq ($(BUILD_KIND),dylib)
TWEAK_NAME := FCMMenu
PRODUCT := FCMMenu
FCMMenu_FILES := Dylib.mm ui/Overlay.mm core/Process.mm
FCMMenu_CFLAGS += -DFCM_INJECTED=1
else
$(error BUILD_KIND must be dylib or tipa)
endif
$(PRODUCT)_CFLAGS += -fobjc-arc -fvisibility=hidden -Os -Wno-deprecated-declarations
$(PRODUCT)_CCFLAGS += -std=c++17
$(PRODUCT)_FRAMEWORKS := UIKit Foundation CoreGraphics QuartzCore
ifeq ($(BUILD_KIND),tipa)
include $(THEOS_MAKE_PATH)/application.mk
after-package::
	@mkdir -p packages Payload
	@cp -R $(THEOS_STAGING_DIR)/Applications/FCMMenu.app Payload/
	@cd . && zip -qr packages/FCMobile-Menu.tipa Payload
	@rm -rf Payload
else
include $(THEOS_MAKE_PATH)/tweak.mk
after-package::
	@mkdir -p packages
	@cp "$(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/FCMMenu.dylib" packages/FCMobile-Menu.dylib
endif
