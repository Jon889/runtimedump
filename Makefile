ARCHS = armv7 arm64
include theos/makefiles/common.mk

TWEAK_NAME = RuntimeDump
RuntimeDump_FILES = Tweak.xm RTBSelectView.m
RuntimeDump_FRAMEWORKS = UIKit
RuntimeDump_PRIVATE_FRAMEWORKS = AirTraffic AirPlayReceiver CoreUtils

include $(THEOS_MAKE_PATH)/tweak.mk

internal-after-install::
	install.exec "killall -9 MobileSafari; open com.apple.mobilesafari"
