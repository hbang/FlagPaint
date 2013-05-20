include theos/makefiles/common.mk

BUNDLE_NAME = FlagPaint
FlagPaint_FILES = $(wildcard *.m)
FlagPaint_INSTALL_PATH = /Library/PreferenceBundles
FlagPaint_FRAMEWORKS = UIKit CoreGraphics
FlagPaint_PRIVATE_FRAMEWORKS = Preferences
FlagPaint_LDFLAGS = -lsubstrate

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FlagPaint.plist$(ECHO_END)
