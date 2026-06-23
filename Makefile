SHELL := /bin/sh

CMAKE ?= cmake
BUILD_TYPE ?= Release
.DEFAULT_GOAL := codecs

ROOT := $(CURDIR)
VENDOR := $(ROOT)/vendor
BUILD := $(ROOT)/build/vendor

.PHONY: codecs webp avif jxl heif clean-codecs

codecs: webp avif jxl heif
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

heif:
	@echo "==> Building libde265"
	@test -d "$(VENDOR)/libde265" || \
		(echo "vendor/libde265 is missing; add the vendored HEVC decoder first." && exit 1)
	@test -d "$(VENDOR)/libheif" || \
		(echo "vendor/libheif is missing; add the vendored HEIF library first." && exit 1)
	$(CMAKE) -S "$(VENDOR)/libde265" -B "$(BUILD)/libde265" \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DCMAKE_INSTALL_PREFIX="$(BUILD)/heif-prefix" \
		-DBUILD_SHARED_LIBS=OFF \
		-DENABLE_SDL=OFF \
		-DENABLE_DECODER=ON \
		-DENABLE_ENCODER=OFF \
		-DENABLE_SHERLOCK265=OFF \
		-DENABLE_INTERNAL_DEVELOPMENT_TOOLS=OFF \
		-DWITH_FUZZERS=OFF
	$(CMAKE) --build "$(BUILD)/libde265" --config "$(BUILD_TYPE)"
	$(CMAKE) --install "$(BUILD)/libde265" --config "$(BUILD_TYPE)"
	@echo "==> Building libheif"
	$(CMAKE) -S "$(VENDOR)/libheif" -B "$(BUILD)/libheif" \
		-DCMAKE_BUILD_TYPE="$(BUILD_TYPE)" \
		-DCMAKE_INSTALL_PREFIX="$(BUILD)/heif-prefix" \
		-DCMAKE_PREFIX_PATH="$(BUILD)/heif-prefix" \
		-DBUILD_SHARED_LIBS=OFF \
		-DENABLE_PLUGIN_LOADING=OFF \
		-DWITH_LIBDE265=ON \
		-DWITH_LIBDE265_PLUGIN=OFF \
		-DWITH_X265=OFF \
		-DWITH_X265_PLUGIN=OFF \
		-DWITH_AOM_DECODER=OFF \
		-DWITH_AOM_DECODER_PLUGIN=OFF \
		-DWITH_AOM_ENCODER=OFF \
		-DWITH_AOM_ENCODER_PLUGIN=OFF \
		-DWITH_DAV1D=OFF \
		-DWITH_DAV1D_PLUGIN=OFF \
		-DWITH_RAV1E=OFF \
		-DWITH_RAV1E_PLUGIN=OFF \
		-DWITH_SvtEnc=OFF \
		-DWITH_SvtEnc_PLUGIN=OFF \
		-DWITH_KVAZAAR=OFF \
		-DWITH_UVG266=OFF \
		-DWITH_VVDEC=OFF \
		-DWITH_VVENC=OFF \
		-DWITH_X264=OFF \
		-DWITH_OpenH264_DECODER=OFF \
		-DWITH_JPEG_DECODER=OFF \
		-DWITH_JPEG_ENCODER=OFF \
		-DWITH_OpenJPEG_DECODER=OFF \
		-DWITH_OpenJPEG_ENCODER=OFF \
		-DWITH_FFMPEG_DECODER=OFF \
		-DWITH_OPENJPH_ENCODER=OFF \
		-DWITH_UNCOMPRESSED_CODEC=OFF \
		-DWITH_LIBSHARPYUV=OFF \
		-DWITH_LIBSHARPYUV_INTERNAL=OFF \
		-DWITH_GDK_PIXBUF=OFF \
		-DWITH_EXAMPLES=OFF \
		-DWITH_EXAMPLE_HEIF_THUMB=OFF \
		-DWITH_EXAMPLE_HEIF_VIEW=OFF \
		-DBUILD_TESTING=OFF \
		-DBUILD_DOCUMENTATION=OFF
	$(CMAKE) --build "$(BUILD)/libheif" --config "$(BUILD_TYPE)"
	$(CMAKE) --install "$(BUILD)/libheif" --config "$(BUILD_TYPE)"

clean-codecs:
	rm -rf "$(BUILD)"
