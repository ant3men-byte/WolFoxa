TARGET := iphone:clang:15.8:15.8
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WolFox

WolFox_FILES = Tweak.x Core.mm Portable.cpp
WolFox_FRAMEWORKS = Foundation UIKit CoreLocation MapKit
WolFox_CFLAGS = -fobjc-arc -std=c++17 -D_USE_MATH_DEFINES

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	cp WolFoxTargetBundles.txt $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/
