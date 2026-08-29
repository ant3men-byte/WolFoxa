TARGET := iphone:clang:14.5:14.0
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = WolFox

WolFox_FILES = Core.mm UI.mm Portable.cpp

WolFox_FRAMEWORKS = Foundation UIKit CoreLocation MapKit

WolFox_CFLAGS = -fobjc-arc -std=c++17 -D_USE_MATH_DEFINES

WolFox_LDFLAGS = -Wl,-install_name,@executable_path/WolFox.dylib

include $(THEOS_MAKE_PATH)/library.mk
