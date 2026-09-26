THEOS ?= /home/hoang/theos
ARCHS := arm64
TARGET := iphone:clang:16.5
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := Bugchid

ifneq ($(USE_OLLVM),)
Bugchid_CFLAGS  += -mllvm -fla -mllvm -bcf -mllvm -sub -mllvm -perFLA=100
Bugchid_CXXFLAGS += $(Bugchid_CFLAGS)
Bugchid_LDFLAGS += -Wl,-S -Wl,-x 
Bugchid_CFLAGS += -mllvm -strcry
endif

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME := Bugchi

$(APPLICATION_NAME)_USE_MODULES := 0
$(APPLICATION_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/drawing_view/*.cpp)
$(APPLICATION_NAME)_FILES += $(wildcard esp/Core/*.mm)
$(APPLICATION_NAME)_FILES += $(wildcard esp/Core/*.cpp)

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(TESTTIPA_CFLAGS))

$(APPLICATION_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wno-unknown-warning-option -Wno-unused-but-set-variable -fvisibility=hidden -fno-rtti -fobjc-arc -Os
$(APPLICATION_NAME)_CFLAGS += -I.
$(APPLICATION_NAME)_CFLAGS += -Iheaders
$(APPLICATION_NAME)_CFLAGS += -Isources
$(APPLICATION_NAME)_CFLAGS += -Isources/KIF
$(APPLICATION_NAME)_CFLAGS += -Ioxorany

$(APPLICATION_NAME)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.dts.bugchi.hud.destroy\""
$(APPLICATION_NAME)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.dts.bugchi.pid\""
$(APPLICATION_NAME)_CCFLAGS += -std=c++17

$(APPLICATION_NAME)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit CoreText Security CFNetwork SystemConfiguration ImageIO

$(APPLICATION_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
$(APPLICATION_NAME)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(APPLICATION_NAME)_RESOURCE_DIRS = ./layout/Resources

$(APPLICATION_NAME)_LDFLAGS += -Wl,-alias,____isOSVersionAtLeast,___isOSVersionAtLeast

include $(THEOS_MAKE_PATH)/application.mk

include $(THEOS_MAKE_PATH)/aggregate.mk

after-package::
	@echo "[*] Packaging .tipa..."
	@rm -rf Payload $(APPLICATION_NAME).tipa
	@mkdir -p Payload
	@cp -r $(THEOS_STAGING_DIR)/Applications/$(APPLICATION_NAME).app Payload/
	@chmod 755 Payload/$(APPLICATION_NAME).app/$(APPLICATION_NAME)
	@zip -rq $(APPLICATION_NAME).tipa Payload
	@rm -rf Payload
	@mkdir -p packages
	@mv $(APPLICATION_NAME).tipa packages/
	@echo "[*] Success: packages/$(APPLICATION_NAME).tipa"