THEOS ?= /home/hoang/theos
ARCHS := arm64
TARGET := iphone:clang:16.5:13.0
DEBUG := 0
FINALPACKAGE := 1
FOR_RELEASE := 1
INSTALL_TARGET_PROCESSES := FreeFire
include $(THEOS)/makefiles/common.mk
TWEAK_NAME := Aimlag
Aimlag_FILES := MiniOverlay.mm MiniRuntime.mm ../esp/Core/PlayerModes.mm ../esp/Core/PlayerModesRemote.S
Aimlag_CFLAGS := -DMIZZE_INJECTED=1 -fobjc-arc -fvisibility=hidden -Os -Wno-unused-function -Wno-unused-variable -Wno-deprecated-declarations -I.. -I../headers -I../sources -I../esp/Core
Aimlag_CCFLAGS := -std=c++17
Aimlag_FRAMEWORKS := UIKit Foundation QuartzCore CoreGraphics
include $(THEOS_MAKE_PATH)/tweak.mk
after-package::
	@mkdir -p packages
	@cp $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/Aimlag.dylib packages/Aimlag.dylib
