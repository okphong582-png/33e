THEOS ?= /home/hoang/theos
ARCHS := arm64
DEBUG = 0
FINALPACKAGE = 1
FOR_RELEASE = 1
BUILD_KIND ?= dylib
MIZZE_OUTPUT_DIR ?= packages
ifeq ($(BUILD_KIND),tipa)
TARGET := iphone:clang:16.5
INSTALL_TARGET_PROCESSES := Bugchi
else
# Keep the SDK separate from the runtime minimum. SF Symbols in the menu
# require iOS 13, while scene and frame-rate APIs are availability-guarded.
TARGET := iphone:clang:16.5:13.0
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
$(MIZZE_PRODUCT)_FILES := $(filter-out sources/StealthDylibInit.mm,$(MIZZE_SOURCES)) esp/Core/SilentAimRemote.S esp/Core/AutoFireRemote.S esp/Core/GhostRemote.S esp/Core/PlayerModesRemote.S
$(MIZZE_PRODUCT)_CODESIGN_FLAGS += -Slayout/entitlements.plist
$(MIZZE_PRODUCT)_RESOURCE_DIRS := ./layout/Resources
else
# In-process overlays use UIKit's native touches. Do not link the standalone
# HUD application, private touch synthesizer (+load), or anti-debug threads.
$(MIZZE_PRODUCT)_FILES := sources/StealthDylibInit.mm sources/InjectedProtection.mm sources/InjectedLicenseController.mm sources/LicenseSession.mm sources/_0xMO353DA.mm sources/_0xViSecureV28.m $(wildcard esp/drawing_view/*.mm esp/drawing_view/*.cpp esp/Core/*.mm esp/Core/*.cpp) esp/Core/AutoFireRemote.S esp/Core/GhostRemote.S esp/Core/PlayerModesRemote.S
$(MIZZE_PRODUCT)_CFLAGS += -DMIZZE_INJECTED=1
$(MIZZE_PRODUCT)_LDFLAGS += -Wl,-dead_strip_dylibs -Wl,-install_name,@rpath/libsubsystem.dylib
endif

sources/KIF/UITouch-KIFAdditions.m_CFLAGS := $(filter-out -mllvm -enable-fco,$(TESTTIPA_CFLAGS))

$(MIZZE_PRODUCT)_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-value -Wno-module-import-in-extern-c -Wno-unknown-warning-option -Wno-unused-but-set-variable -fvisibility=hidden -fno-rtti -Os
$(MIZZE_PRODUCT)_CFLAGS += -I. -Iheaders -Isources -Isources/KIF -Ioxorany -Iobfuscation

$(MIZZE_PRODUCT)_CFLAGS += -DNOTIFY_DESTROY_HUD="\"com.dts.bugchi.hud.destroy\""
$(MIZZE_PRODUCT)_CFLAGS += -DPID_PATH="@\"/var/mobile/Library/Caches/com.dts.bugchi.pid\""
# One seed for every translation unit; __TIME__ can differ during parallel builds.
MIZZE_BUILD_SEED := $(shell git rev-parse --short=12 HEAD 2>/dev/null)
ifeq ($(MIZZE_BUILD_SEED),)
MIZZE_BUILD_SEED := 4D495A5A4533
endif
$(MIZZE_PRODUCT)_CFLAGS += -DOBFUSCATION_BUILD_SEED=0x$(MIZZE_BUILD_SEED)ULL
$(MIZZE_PRODUCT)_CCFLAGS += -std=c++17

$(MIZZE_PRODUCT)_FRAMEWORKS += CoreGraphics QuartzCore UIKit Security
ifeq ($(BUILD_KIND),tipa)
$(MIZZE_PRODUCT)_FRAMEWORKS += CoreServices IOKit CoreText CFNetwork SystemConfiguration ImageIO
endif

ifeq ($(BUILD_KIND),tipa)
$(MIZZE_PRODUCT)_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
endif

ifeq ($(BUILD_KIND),tipa)
$(MIZZE_PRODUCT)_LDFLAGS += -Wl,-alias,____isOSVersionAtLeast,___isOSVersionAtLeast
endif

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
	@mkdir -p "$(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Application Support/iOSViet/"
	@cp -r layout/Resources/* "$(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/Application Support/iOSViet/"

after-package::
	@echo "[*] Packaging stealth dylib and deb..."
	@mkdir -p "$(MIZZE_OUTPUT_DIR)"
	@cp "$(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries/iOSViet.dylib" "$(MIZZE_OUTPUT_DIR)/libsubsystem.dylib"
	@echo "[*] Success: $(MIZZE_OUTPUT_DIR)/libsubsystem.dylib"
endif
