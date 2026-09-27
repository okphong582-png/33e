THEOS ?= /home/hoang/theos
ARCHS := arm64
TARGET := iphone:clang:16.5
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
INSTALL_TARGET_PROCESSES := FreeFire

ifneq ($(USE_OLLVM),)
iOSViet_CFLAGS  += -mllvm -fla -mllvm -bcf -mllvm -sub -mllvm -perFLA=100
iOSViet_CXXFLAGS += $(iOSViet_CFLAGS)
iOSViet_LDFLAGS += -Wl,-S -Wl,-x 
iOSViet_CFLAGS += -mllvm -strcry
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := iOSViet

$(TWEAK_NAME)_USE_MODULES := 0
$(TWEAK_NAME)_FILES += $(wildcard sources/*.mm sources/*.m)
$(TWEAK_NAME)_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
$(TWEAK_NAME)_FILES += $(wildcard esp/drawing_view/*.mm)
$(TWEAK_NAME)_FILES += $(wildcard esp/drawing_view/*.cpp)
$(TWEAK_NAME)_FILES += $(wildcard esp/Core/*.mm)
$(TWEAK_NAME)_FILES += $(wildcard esp/Core/*.cpp)

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(TESTTIPA_CFLAGS))

$(TWEAK_NAME)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wno-unknown-warning-option -Wno-unused-but-set-variable -fvisibility=hidden -fno-rtti -Os
$(TWEAK_NAME)_CFLAGS += -I.
$(TWEAK_NAME)_CFLAGS += -Iheaders
$(TWEAK_NAME)_CFLAGS += -Isources
$(TWEAK_NAME)_CFLAGS += -Isources/KIF
$(TWEAK_NAME)_CFLAGS += -Ioxorany

$(TWEAK_NAME)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.dts.bugchi.hud.destroy\""
$(TWEAK_NAME)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.dts.bugchi.pid\""
$(TWEAK_NAME)_CCFLAGS += -std=c++17

$(TWEAK_NAME)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit CoreText Security CFNetwork SystemConfiguration ImageIO

$(TWEAK_NAME)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices

$(TWEAK_NAME)_LDFLAGS += -Wl,-alias,____isOSVersionAtLeast,___isOSVersionAtLeast

include $(THEOS_MAKE_PATH)/tweak.mk

before-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support/iOSViet/
	@cp -r layout/Resources/* $(THEOS_STAGING_DIR)/Library/Application\ Support/iOSViet/ 2>/dev/null || true
	@cp layout/Resources/Dragon\ Ball\ Z\ Rage\ GIF.gif $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/ 2>/dev/null || true

after-package::
	@echo "[*] Packaging stealth dylib..."
	@mkdir -p packages
	@cp .theos/obj/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp .theos/obj/debug/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp .theos/obj/iOSViet.dylib packages/iOSViet.dylib 2>/dev/null || true
	@echo "[*] Success: packages/libsubsystem.dylib"