THEOS ?= /opt/theos
ARCHS = arm64
TARGET = iphone:clang:16.5:15.0
FINALPACKAGE = 1
FOR_RELEASE = 1
include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MizzeFFVN
MizzeFFVN_USE_MODULES = 0
MizzeFFVN_FILES = sources/KernelLauncher.mm sources/MizzeLicense.mm sources/_0xHAPP827.mm sources/HUDHelper.mm sources/HUDMainApplication.mm sources/_0xHMWin927.mm sources/_0xHUMDE2872_.mm sources/_0xtsE28vent_.mm sources/_0xMO353DA.mm sources/_0xViSecureV28.m sources/PlatformVersion.mm
MizzeFFVN_FILES += $(wildcard sources/KIF/*.m sources/KIF/*.mm)
MizzeFFVN_FILES += $(filter-out esp/Core/_0xPDFFFF27.mm,$(wildcard esp/Core/*.mm esp/Core/*.cpp esp/drawing_view/*.mm esp/drawing_view/*.cpp))
MizzeFFVN_FILES += esp/Core/AutoFireRemote.S esp/Core/GhostRemote.S esp/Core/PlayerModesRemote.S esp/Core/SilentAimRemote.S
MizzeFFVN_CFLAGS = -DMIZZE_GAME_VN=1 -DMIZZE_KERNEL_BACKEND=1 -DMIZZE_GAME_PROCESS_NAME=\"FreeFireVN\" -DOBFUSCATION_BUILD_SEED=0x4D495A5A4533ULL
MizzeFFVN_CFLAGS += -DNOTIFY_DESTROY_HUD=\"com.mizze.ffvn.kernel.hud.destroy\" -DPID_PATH=@\"/var/mobile/Library/Caches/com.mizze.ffvn.kernel.pid\"
MizzeFFVN_CFLAGS += -fobjc-arc -fblocks -fvisibility=hidden -fno-rtti -Os -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unknown-warning-option
MizzeFFVN_CFLAGS += -I. -Iheaders -Isources -Isources/KIF -Ioxorany -Iobfuscation
MizzeFFVN_CCFLAGS = -std=c++17
MizzeFFVN_LDFLAGS += -Wl,-S,-x
MizzeFFVN_FRAMEWORKS = Network UIKit Foundation CoreFoundation CoreGraphics QuartzCore Security CoreServices IOKit CoreText CFNetwork SystemConfiguration ImageIO
MizzeFFVN_PRIVATE_FRAMEWORKS = BackBoardServices GraphicsServices SpringBoardServices
MizzeFFVN_CODESIGN_FLAGS = -Sentitlements.plist
MizzeFFVN_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/application.mk
