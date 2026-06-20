## Raw libwebp bindings.
##
## This module exposes selected public C APIs from the vendored libwebp copy.
## It deliberately keeps libwebp's own naming, pointer types, return codes, and
## memory ownership rules. Functions that return encoded or decoded buffers
## generally allocate with libwebp and must be released with `WebPFree`.
##
## The binding links `build/vendor/libwebp/libwebp.a`; run `make codecs` before
## importing this module in a fresh checkout.

import std/os
import pixerver2/codecs/private/sharpyuv_link

const
  PixerverRoot = currentSourcePath().parentDir().parentDir().parentDir().parentDir()
  WebPInclude = PixerverRoot / "vendor/libwebp/src"
  WebPBuild = PixerverRoot / "build/vendor/libwebp"

{.passC: "-I" & WebPInclude.}
{.passL: WebPBuild / "libwebp.a".}

type
  ## Incremental decoder handle owned by libwebp.
  WebPIDecoder* {.importc: "WebPIDecoder", header: "<webp/decode.h>",
                  incompleteStruct.} = object
  ## Decoder output buffer used by advanced decode config APIs.
  WebPDecBuffer* {.importc: "WebPDecBuffer", header: "<webp/decode.h>",
                   incompleteStruct.} = object
  ## Advanced decoder configuration. Use libwebp init helpers before use.
  WebPDecoderConfig* {.importc: "WebPDecoderConfig", header: "<webp/decode.h>",
                       incompleteStruct.} = object
  ## Bitstream metadata returned by `WebPGetFeaturesInternal`.
  WebPBitstreamFeatures* {.importc: "WebPBitstreamFeatures",
                           header: "<webp/decode.h>", incompleteStruct.} = object
  ## Encoder configuration. Use `WebPConfigInitInternal` before use.
  WebPConfig* {.importc: "WebPConfig", header: "<webp/encode.h>",
                incompleteStruct.} = object
  ## Encoder input/output picture structure managed by libwebp helpers.
  WebPPicture* {.importc: "WebPPicture", header: "<webp/encode.h>",
                 incompleteStruct.} = object
  ## libwebp memory writer structure for advanced custom-output encoding.
  WebPMemoryWriter* {.importc: "WebPMemoryWriter", header: "<webp/encode.h>",
                      incompleteStruct.} = object

  ## libwebp decode status values.
  VP8StatusCode* {.size: sizeof(cint).} = enum
    VP8_STATUS_OK = 0
    VP8_STATUS_OUT_OF_MEMORY
    VP8_STATUS_INVALID_PARAM
    VP8_STATUS_BITSTREAM_ERROR
    VP8_STATUS_UNSUPPORTED_FEATURE
    VP8_STATUS_SUSPENDED
    VP8_STATUS_USER_ABORT
    VP8_STATUS_NOT_ENOUGH_DATA

## Returns libwebp decoder version as libwebp's packed integer format.
proc WebPGetDecoderVersion*(): cint {.importc, header: "<webp/decode.h>".}

## Returns libwebp encoder version as libwebp's packed integer format.
proc WebPGetEncoderVersion*(): cint {.importc, header: "<webp/encode.h>".}

## Allocates memory through libwebp's allocator.
proc WebPMalloc*(size: csize_t): pointer {.importc, header: "<webp/types.h>".}

## Releases memory returned by libwebp APIs such as `WebPDecodeRGBA` and
## `WebPEncodeRGB`.
proc WebPFree*(p: pointer) {.importc, header: "<webp/types.h>".}

## Reads WebP image dimensions without fully decoding the image.
proc WebPGetInfo*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): cint {.
  importc, header: "<webp/decode.h>".}

## Decodes a WebP byte stream to a newly allocated RGBA buffer.
proc WebPDecodeRGBA*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes a WebP byte stream to a newly allocated ARGB buffer.
proc WebPDecodeARGB*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes a WebP byte stream to a newly allocated BGRA buffer.
proc WebPDecodeBGRA*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes a WebP byte stream to a newly allocated RGB buffer.
proc WebPDecodeRGB*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes a WebP byte stream to a newly allocated BGR buffer.
proc WebPDecodeBGR*(data: ptr uint8; dataSize: csize_t; width, height: ptr cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes WebP RGBA pixels into caller-owned memory.
proc WebPDecodeRGBAInto*(data: ptr uint8; dataSize: csize_t; outputBuffer: ptr uint8;
                         outputBufferSize: csize_t; outputStride: cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Decodes WebP RGB pixels into caller-owned memory.
proc WebPDecodeRGBInto*(data: ptr uint8; dataSize: csize_t; outputBuffer: ptr uint8;
                        outputBufferSize: csize_t; outputStride: cint): ptr uint8 {.
  importc, header: "<webp/decode.h>".}

## Populates bitstream feature metadata using libwebp's ABI-versioned entry.
proc WebPGetFeaturesInternal*(data: ptr uint8; dataSize: csize_t;
                              features: ptr WebPBitstreamFeatures;
                              abiVersion: cint): VP8StatusCode {.
  importc, header: "<webp/decode.h>".}

## Initializes an advanced decoder config with libwebp's ABI-versioned entry.
proc WebPInitDecoderConfigInternal*(config: ptr WebPDecoderConfig;
                                    abiVersion: cint): cint {.
  importc, header: "<webp/decode.h>".}

## Validates an initialized advanced decoder config.
proc WebPValidateDecoderConfig*(config: ptr WebPDecoderConfig): cint {.
  importc, header: "<webp/decode.h>".}

## Decodes using an initialized `WebPDecoderConfig`.
proc WebPDecode*(data: ptr uint8; dataSize: csize_t;
                 config: ptr WebPDecoderConfig): VP8StatusCode {.
  importc, header: "<webp/decode.h>".}

## Frees allocations held by a `WebPDecBuffer`.
proc WebPFreeDecBuffer*(buffer: ptr WebPDecBuffer) {.
  importc, header: "<webp/decode.h>".}

## Encodes RGB pixels to lossy WebP. Output is libwebp-owned until `WebPFree`.
proc WebPEncodeRGB*(rgb: ptr uint8; width, height, stride: cint;
                    qualityFactor: cfloat; output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Encodes BGR pixels to lossy WebP. Output is libwebp-owned until `WebPFree`.
proc WebPEncodeBGR*(bgr: ptr uint8; width, height, stride: cint;
                    qualityFactor: cfloat; output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Encodes RGBA pixels to lossy WebP. Output is libwebp-owned until `WebPFree`.
proc WebPEncodeRGBA*(rgba: ptr uint8; width, height, stride: cint;
                     qualityFactor: cfloat; output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Encodes BGRA pixels to lossy WebP. Output is libwebp-owned until `WebPFree`.
proc WebPEncodeBGRA*(bgra: ptr uint8; width, height, stride: cint;
                     qualityFactor: cfloat; output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Encodes RGB pixels to lossless WebP. Output is libwebp-owned until `WebPFree`.
proc WebPEncodeLosslessRGB*(rgb: ptr uint8; width, height, stride: cint;
                            output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Encodes RGBA pixels to lossless WebP. Output is libwebp-owned until
## `WebPFree`.
proc WebPEncodeLosslessRGBA*(rgba: ptr uint8; width, height, stride: cint;
                             output: ptr ptr uint8): csize_t {.
  importc, header: "<webp/encode.h>".}

## Initializes `WebPConfig` with preset, quality, and ABI version.
proc WebPConfigInitInternal*(config: ptr WebPConfig; preset: cint;
                             quality: cfloat; abiVersion: cint): cint {.
  importc, header: "<webp/encode.h>".}

## Validates a `WebPConfig` before advanced encoding.
proc WebPValidateConfig*(config: ptr WebPConfig): cint {.
  importc, header: "<webp/encode.h>".}

## Initializes `WebPPicture` with libwebp's ABI-versioned entry.
proc WebPPictureInitInternal*(picture: ptr WebPPicture; abiVersion: cint): cint {.
  importc, header: "<webp/encode.h>".}

## Allocates picture buffers according to fields set on `WebPPicture`.
proc WebPPictureAlloc*(picture: ptr WebPPicture): cint {.
  importc, header: "<webp/encode.h>".}

## Frees buffers owned by a `WebPPicture`.
proc WebPPictureFree*(picture: ptr WebPPicture) {.
  importc, header: "<webp/encode.h>".}

## Imports caller-owned RGB pixels into a `WebPPicture`.
proc WebPPictureImportRGB*(picture: ptr WebPPicture; rgb: ptr uint8;
                           rgbStride: cint): cint {.
  importc, header: "<webp/encode.h>".}

## Imports caller-owned RGBA pixels into a `WebPPicture`.
proc WebPPictureImportRGBA*(picture: ptr WebPPicture; rgba: ptr uint8;
                            rgbaStride: cint): cint {.
  importc, header: "<webp/encode.h>".}

## Encodes a prepared `WebPPicture` using a prepared `WebPConfig`.
proc WebPEncode*(config: ptr WebPConfig; picture: ptr WebPPicture): cint {.
  importc, header: "<webp/encode.h>".}
