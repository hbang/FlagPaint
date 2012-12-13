include theos/makefiles/common.mk

THEOS_BUILD_DIR = debs
TARGET = iphone:clang:5.1:5.0

TWEAK_NAME = FlagPaint
FlagPaint_FILES = Tweak.xm UIColor-Expanded.m
FlagPaint_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
