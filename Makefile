ARCHS = armv7 arm64
include theos/makefiles/common.mk

TWEAK_NAME = RuntimeDump
RuntimeDump_FILES = Tweak.xm
RuntimeDump_FRAMEWORKS = UIKit
RuntimeDump_PRIVATE_FRAMEWORKS = AirTraffic AirPlayReceiver CoreUtils

include $(THEOS_MAKE_PATH)/tweak.mk
