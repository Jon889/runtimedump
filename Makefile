include theos/makefiles/common.mk

TWEAK_NAME = RuntimeDump
RuntimeDump_FILES = Tweak.xm ioapi.c unzip.c zip.c FileInZipInfo.m ZipException.m ZipFile.m ZipReadStream.m ZipWriteStream.m adler32.c compress.c crc32.c deflate.c gzclose.c gzlib.c gzread.c gzwrite.c infback.c inffast.c inflate.c inftrees.c trees.c uncompr.c zutil.c
RuntimeDump_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
