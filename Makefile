# NoUpdateChecker Makefile for Theos

THEOS_DEVICE_IP = localhost
THEOS_DEVICE_PORT = 2222

PACKAGE_NAME = com.noupdate.checker
PACKAGE_VERSION = 1.0.0
PACKAGE_ARCH = iphoneos-arm

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = NoUpdateChecker
NoUpdateChecker_FILES = NoUpdateChecker.m
NoUpdateChecker_CFLAGS = -fobjc-arc
NoUpdateChecker_LDFLAGS = - framework Foundation -framework UIKit -framework StoreKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"