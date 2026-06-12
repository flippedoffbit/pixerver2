SHELL := /bin/sh

CMAKE ?= cmake
BUILD_TYPE ?= Release

ROOT := $(CURDIR)
VENDOR := $(ROOT)/vendor
BUILD := $(ROOT)/build/vendor

.PHONY: codecs webp avif jxl clean-codecs

codecs: webp avif jxl
	@echo "All codec static builds completed."

webp:
	@echo "==> Building libwebp"
	$(CMAKE) -S "$(VENDOR)/libwebp" -B "$(BUILD)/libwebp" \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DBUILD_SHARED_LIBS=OFF \
		-DWEBP_BUILD_ANIM_UTILS=OFF \
		-DWEBP_BUILD_CWEBP=OFF \
		-DWEBP_BUILD_DWEBP=OFF \
		-DWEBP_BUILD_GIF2WEBP=OFF \
		-DWEBP_BUILD_IMG2WEBP=OFF \
		-DWEBP_BUILD_VWEBP=OFF \
		-DWEBP_BUILD_WEBPINFO=OFF \
		-DWEBP_BUILD_WEBPMUX=OFF \
		-DWEBP_BUILD_EXTRAS=OFF
	$(CMAKE) --build "$(BUILD)/libwebp" --config "$(BUILD_TYPE)"

avif:
	@echo "==> Building libavif"
	$(CMAKE) -S "$(VENDOR)/libavif" -B "$(BUILD)/libavif" \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DBUILD_SHARED_LIBS=OFF \
		-DAVIF_BUILD_APPS=OFF \
		-DAVIF_BUILD_TESTS=OFF \
		-DAVIF_BUILD_EXAMPLES=OFF \
		-DAVIF_LIBYUV=LOCAL \
		-DAVIF_CODEC_AOM=LOCAL
	$(CMAKE) --build "$(BUILD)/libavif" --config "$(BUILD_TYPE)"

jxl:
	@echo "==> Building libjxl"
	$(CMAKE) -S "$(VENDOR)/libjxl" -B "$(BUILD)/libjxl" \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTING=OFF \
		-DJPEGXL_ENABLE_TOOLS=OFF \
		-DJPEGXL_ENABLE_MANPAGES=OFF \
		-DJPEGXL_ENABLE_BENCHMARK=OFF \
		-DJPEGXL_ENABLE_EXAMPLES=OFF \
		-DJPEGXL_ENABLE_PLUGINS=OFF \
		-DJPEGXL_ENABLE_DOXYGEN=OFF \
		-DJPEGXL_ENABLE_OPENEXR=OFF
	$(CMAKE) --build "$(BUILD)/libjxl" --config "$(BUILD_TYPE)"

clean-codecs:
	rm -rf "$(BUILD)"