TARGET = :clang::5.0

include theos/makefiles/common.mk

THEOS_BUILD_DIR = debs

TWEAK_NAME = FlagPaint
FlagPaint_FILES = Tweak.xm HBFPColorArt.m
#FlagPaint_FILES = Tweak.xm UIColor-Expanded.m HBFPColorArt.m
FlagPaint_FRAMEWORKS = UIKit CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk
