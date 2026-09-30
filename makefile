THEOS ?= /home/hoang/theos
ARCHS := arm64
TARGET := iphone:clang:16.5
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
BUILD_KIND ?= dylib
ifeq ($(BUILD_KIND),tipa)
INSTALL_TARGET_PROCESSES := Bugchi
else
INSTALL_TARGET_PROCESSES := FreeFire
endif

ifneq ($(USE_OLLVM),)
iOSViet_CFLAGS  += -mllvm -fla -mllvm -bcf -mllvm -sub -mllvm -perFLA=100
iOSViet_CXXFLAGS += $(iOSViet_CFLAGS)
iOSViet_LDFLAGS += -Wl,-S -Wl,-x 
iOSViet_CFLAGS += -mllvm -strcry
endif

include $(THEOS)/makefiles/common.mk

ifeq ($(BUILD_KIND),tipa)
APPLICATION_NAME := Bugchi
MIZZE_PRODUCT := Bugchi
else
TWEAK_NAME := iOSViet
MIZZE_PRODUCT := iOSViet
endif

$(MIZZE_PRODUCT)_USE_MODULES := 0
MIZZE_SOURCES := $(wildcard sources/*.mm sources/*.m sources/KIF/*.mm sources/KIF/*.m esp/drawing_view/*.mm esp/drawing_view/*.cpp esp/Core/*.mm esp/Core/*.cpp)
ifeq ($(BUILD_KIND),tipa)
$(MIZZE_PRODUCT)_FILES := $(filter-out sources/StealthDylibInit.mm,$(MIZZE_SOURCES))
$(MIZZE_PRODUCT)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(MIZZE_PRODUCT)_RESOURCE_DIRS := ./layout/Resources
else
$(MIZZE_PRODUCT)_FILES := $(filter-out sources/_0xHAPP827.mm,$(MIZZE_SOURCES))
$(MIZZE_PRODUCT)_CFLAGS += -DMIZZE_INJECTED=1
endif

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(TESTTIPA_CFLAGS))

$(MIZZE_PRODUCT)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wno-unknown-warning-option -Wno-unused-but-set-variable -fvisibility=hidden -fno-rtti -Os
$(MIZZE_PRODUCT)_CFLAGS += -I. -Iheaders -Isources -Isources/KIF -Ioxorany -Iobfuscation

$(MIZZE_PRODUCT)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.dts.bugchi.hud.destroy\""
$(MIZZE_PRODUCT)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.dts.bugchi.pid\""
$(MIZZE_PRODUCT)_CCFLAGS += -std=c++17

$(MIZZE_PRODUCT)_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit CoreText Security CFNetwork SystemConfiguration ImageIO

$(MIZZE_PRODUCT)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices

$(MIZZE_PRODUCT)_LDFLAGS += -Wl,-alias,____isOSVersionAtLeast,___isOSVersionAtLeast

ifeq ($(BUILD_KIND),tipa)
include $(THEOS_MAKE_PATH)/application.mk
include $(THEOS_MAKE_PATH)/aggregate.mk

after-package::
	@rm -rf Payload
	@mkdir -p Payload packages
	@cp -r $(THEOS_STAGING_DIR)/Applications/Bugchi.app Payload/
	@chmod 755 Payload/Bugchi.app/Bugchi
	@rm -f packages/Mizze.tipa
	@zip -rq packages/Mizze.tipa Payload
	@rm -rf Payload
else
include $(THEOS_MAKE_PATH)/tweak.mk

stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/Application\ Support/iOSViet/
	@cp -r layout/Resources/* $(THEOS_STAGING_DIR)/Library/Application\ Support/iOSViet/ 2>/dev/null || true

after-package::
	@echo "[*] Packaging stealth dylib and deb..."
	@mkdir -p packages
	@cp .theos/obj/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp .theos/obj/debug/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/iOSViet.dylib packages/libsubsystem.dylib 2>/dev/null || cp .theos/obj/iOSViet.dylib packages/iOSViet.dylib 2>/dev/null || true
	@echo "[*] Success: packages/libsubsystem.dylib"
endif
