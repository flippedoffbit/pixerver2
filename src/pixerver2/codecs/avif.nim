## Raw libavif bindings.
##
## This module exposes selected public C APIs from the vendored libavif copy.
## The surface stays close to libavif: C names, explicit pointers, enum result
## codes, and libavif memory ownership rules are preserved.
##
## `avifRWData` buffers filled by encoder APIs must be released with
## `avifRWDataFree`. `avifImage`, `avifDecoder`, and `avifEncoder` pointers
## must be destroyed with their matching libavif destroy functions.
##
## The binding links `build/vendor/libavif/libavif.a` and its vendored AOM,
## libyuv, and SharpYUV dependencies. Run `make codecs` before importing this
## module in a fresh checkout.

import std/os
import pixerver2/codecs/private/sharpyuv_link

const
  PixerverRoot = currentSourcePath().parentDir().parentDir().parentDir().parentDir()
  AvifInclude = PixerverRoot / "vendor/libavif/include"
  AvifBuild = PixerverRoot / "build/vendor/libavif"

{.passC: "-I" & AvifInclude.}
{.passL: AvifBuild / "libavif.a".}
{.passL: AvifBuild / "_deps/libaom-build/libaom.a".}
{.passL: AvifBuild / "_deps/libyuv-build/libyuv.a".}
when defined(linux):
  {.passL: "-lm".}

type
  ## libavif boolean value. The C API uses `int`, not Nim `bool`.
  avifBool* = cint

  ## Bitmask for image plane allocation/freeing.
  avifPlanesFlags* = uint32

  ## Bitmask for advanced encoder add-image flags.
  avifAddImageFlags* = uint32

  ## Opaque AVIF image handle allocated by libavif.
  avifImage* {.importc: "avifImage", header: "<avif/avif.h>",
               incompleteStruct.} = object
  ## Opaque decoder handle allocated by `avifDecoderCreate`.
  avifDecoder* {.importc: "avifDecoder", header: "<avif/avif.h>",
                 incompleteStruct.} = object
  ## Opaque encoder handle allocated by `avifEncoderCreate`.
  avifEncoder* {.importc: "avifEncoder", header: "<avif/avif.h>",
                 incompleteStruct.} = object
  ## Opaque IO handle used by advanced decoder IO APIs.
  avifIO* {.importc: "avifIO", header: "<avif/avif.h>",
            incompleteStruct.} = object
  ## Diagnostics object used by selected libavif APIs.
  avifDiagnostics* {.importc: "avifDiagnostics", header: "<avif/avif.h>",
                     incompleteStruct.} = object

  ## Borrowed read-only byte span.
  avifROData* {.importc: "avifROData", header: "<avif/avif.h>".} = object
    data*: ptr uint8
    size*: csize_t

  ## Mutable byte buffer owned by libavif when filled by libavif APIs.
  avifRWData* {.importc: "avifRWData", header: "<avif/avif.h>".} = object
    data*: ptr uint8
    size*: csize_t

  ## libavif result codes returned by most fallible APIs.
  avifResult* {.size: sizeof(cint).} = enum
    AVIF_RESULT_OK = 0
    AVIF_RESULT_UNKNOWN_ERROR = 1
    AVIF_RESULT_INVALID_FTYP = 2
    AVIF_RESULT_NO_CONTENT = 3
    AVIF_RESULT_NO_YUV_FORMAT_SELECTED = 4
    AVIF_RESULT_REFORMAT_FAILED = 5
    AVIF_RESULT_UNSUPPORTED_DEPTH = 6
    AVIF_RESULT_ENCODE_COLOR_FAILED = 7
    AVIF_RESULT_ENCODE_ALPHA_FAILED = 8
    AVIF_RESULT_BMFF_PARSE_FAILED = 9
    AVIF_RESULT_MISSING_IMAGE_ITEM = 10
    AVIF_RESULT_DECODE_COLOR_FAILED = 11
    AVIF_RESULT_DECODE_ALPHA_FAILED = 12
    AVIF_RESULT_COLOR_ALPHA_SIZE_MISMATCH = 13
    AVIF_RESULT_ISPE_SIZE_MISMATCH = 14
    AVIF_RESULT_NO_CODEC_AVAILABLE = 15
    AVIF_RESULT_NO_IMAGES_REMAINING = 16
    AVIF_RESULT_INVALID_EXIF_PAYLOAD = 17
    AVIF_RESULT_INVALID_IMAGE_GRID = 18
    AVIF_RESULT_INVALID_CODEC_SPECIFIC_OPTION = 19
    AVIF_RESULT_TRUNCATED_DATA = 20
    AVIF_RESULT_IO_NOT_SET = 21
    AVIF_RESULT_IO_ERROR = 22
    AVIF_RESULT_WAITING_ON_IO = 23
    AVIF_RESULT_INVALID_ARGUMENT = 24
    AVIF_RESULT_NOT_IMPLEMENTED = 25
    AVIF_RESULT_OUT_OF_MEMORY = 26
    AVIF_RESULT_CANNOT_CHANGE_SETTING = 27
    AVIF_RESULT_INCOMPATIBLE_IMAGE = 28
    AVIF_RESULT_INTERNAL_ERROR = 29
    AVIF_RESULT_ENCODE_GAIN_MAP_FAILED = 30
    AVIF_RESULT_DECODE_GAIN_MAP_FAILED = 31
    AVIF_RESULT_INVALID_TONE_MAPPED_IMAGE = 32
    AVIF_RESULT_ENCODE_SAMPLE_TRANSFORM_FAILED = 33
    AVIF_RESULT_DECODE_SAMPLE_TRANSFORM_FAILED = 34

  ## Plane mask values for YUV and alpha buffers.
  avifPlanesFlag* {.size: sizeof(cint).} = enum
    AVIF_PLANES_YUV = 1 shl 0
    AVIF_PLANES_A = 1 shl 1
    AVIF_PLANES_ALL = 0xff

  ## YUV pixel layouts used by libavif images.
  avifPixelFormat* {.size: sizeof(cint).} = enum
    AVIF_PIXEL_FORMAT_NONE = 0
    AVIF_PIXEL_FORMAT_YUV444
    AVIF_PIXEL_FORMAT_YUV422
    AVIF_PIXEL_FORMAT_YUV420
    AVIF_PIXEL_FORMAT_YUV400
    AVIF_PIXEL_FORMAT_COUNT

  ## Interleaved RGB memory layouts used by `avifRGBImage`.
  avifRGBFormat* {.size: sizeof(cint).} = enum
    AVIF_RGB_FORMAT_RGB = 0
    AVIF_RGB_FORMAT_RGBA
    AVIF_RGB_FORMAT_ARGB
    AVIF_RGB_FORMAT_BGR
    AVIF_RGB_FORMAT_BGRA
    AVIF_RGB_FORMAT_ABGR
    AVIF_RGB_FORMAT_RGB_565
    AVIF_RGB_FORMAT_GRAY
    AVIF_RGB_FORMAT_GRAYA
    AVIF_RGB_FORMAT_AGRAY
    AVIF_RGB_FORMAT_COUNT

  ## Chroma upsampling strategy for YUV-to-RGB conversion.
  avifChromaUpsampling* {.size: sizeof(cint).} = enum
    AVIF_CHROMA_UPSAMPLING_AUTOMATIC = 0
    AVIF_CHROMA_UPSAMPLING_FASTEST = 1
    AVIF_CHROMA_UPSAMPLING_BEST_QUALITY = 2
    AVIF_CHROMA_UPSAMPLING_NEAREST = 3
    AVIF_CHROMA_UPSAMPLING_BILINEAR = 4

  ## Chroma downsampling strategy for RGB-to-YUV conversion.
  avifChromaDownsampling* {.size: sizeof(cint).} = enum
    AVIF_CHROMA_DOWNSAMPLING_AUTOMATIC = 0
    AVIF_CHROMA_DOWNSAMPLING_FASTEST = 1
    AVIF_CHROMA_DOWNSAMPLING_BEST_QUALITY = 2
    AVIF_CHROMA_DOWNSAMPLING_AVERAGE = 3
    AVIF_CHROMA_DOWNSAMPLING_SHARP_YUV = 4

  ## Decoder source selection for still images versus tracks.
  avifDecoderSource* {.size: sizeof(cint).} = enum
    AVIF_DECODER_SOURCE_AUTO = 0
    AVIF_DECODER_SOURCE_PRIMARY_ITEM = 1
    AVIF_DECODER_SOURCE_TRACKS = 2

  ## Public libavif RGB image view/buffer descriptor.
  avifRGBImage* {.importc: "avifRGBImage", header: "<avif/avif.h>".} = object
    width*: uint32
    height*: uint32
    depth*: uint32
    format*: avifRGBFormat
    chromaUpsampling*: avifChromaUpsampling
    chromaDownsampling*: avifChromaDownsampling
    avoidLibYUV*: avifBool
    ignoreAlpha*: avifBool
    alphaPremultiplied*: avifBool
    isFloat*: avifBool
    maxThreads*: cint
    pixels*: ptr uint8
    rowBytes*: uint32

## Returns libavif's version string.
proc avifVersion*(): cstring {.importc, header: "<avif/avif.h>".}

## Writes codec backend version details into a caller-provided 256-byte buffer.
proc avifCodecVersions*(outBuffer: ptr char) {.importc, header: "<avif/avif.h>".}

## Returns the linked libyuv version, or 0 when libyuv support is unavailable.
proc avifLibYUVVersion*(): cuint {.importc, header: "<avif/avif.h>".}

## Allocates memory using libavif's allocator.
proc avifAlloc*(size: csize_t): pointer {.importc, header: "<avif/avif.h>".}

## Releases memory allocated by libavif.
proc avifFree*(p: pointer) {.importc, header: "<avif/avif.h>".}

## Converts a libavif result code to a static C string.
proc avifResultToString*(result: avifResult): cstring {.importc, header: "<avif/avif.h>".}

## Resizes a libavif mutable byte buffer.
proc avifRWDataRealloc*(raw: ptr avifRWData; newSize: csize_t): avifResult {.
  importc, header: "<avif/avif.h>".}

## Copies bytes into a libavif mutable byte buffer.
proc avifRWDataSet*(raw: ptr avifRWData; data: ptr uint8; len: csize_t): avifResult {.
  importc, header: "<avif/avif.h>".}

## Releases storage held by an `avifRWData`.
proc avifRWDataFree*(raw: ptr avifRWData) {.importc, header: "<avif/avif.h>".}

## Converts a YUV pixel format enum to a static C string.
proc avifPixelFormatToString*(format: avifPixelFormat): cstring {.
  importc, header: "<avif/avif.h>".}

## Returns the channel count for an RGB memory layout.
proc avifRGBFormatChannelCount*(format: avifRGBFormat): uint32 {.
  importc, header: "<avif/avif.h>".}

## Returns nonzero when an RGB memory layout includes alpha.
proc avifRGBFormatHasAlpha*(format: avifRGBFormat): avifBool {.
  importc, header: "<avif/avif.h>".}

## Returns nonzero when an RGB memory layout is grayscale.
proc avifRGBFormatIsGray*(format: avifRGBFormat): avifBool {.
  importc, header: "<avif/avif.h>".}

## Allocates an AVIF image with fixed dimensions, depth, and YUV format.
proc avifImageCreate*(width, height, depth: uint32;
                      yuvFormat: avifPixelFormat): ptr avifImage {.
  importc, header: "<avif/avif.h>".}

## Allocates an empty image, usually for decoder output.
proc avifImageCreateEmpty*(): ptr avifImage {.importc, header: "<avif/avif.h>".}

## Destroys an image allocated by libavif.
proc avifImageDestroy*(image: ptr avifImage) {.importc, header: "<avif/avif.h>".}

## Allocates selected image planes on an `avifImage`.
proc avifImageAllocatePlanes*(image: ptr avifImage;
                              planes: avifPlanesFlags): avifResult {.
  importc, header: "<avif/avif.h>".}

## Frees selected image planes on an `avifImage`.
proc avifImageFreePlanes*(image: ptr avifImage; planes: avifPlanesFlags) {.
  importc, header: "<avif/avif.h>".}

## Returns nonzero when image planes use 16-bit samples.
proc avifImageUsesU16*(image: ptr avifImage): avifBool {.
  importc, header: "<avif/avif.h>".}

## Returns nonzero when the image has no visible alpha.
proc avifImageIsOpaque*(image: ptr avifImage): avifBool {.
  importc, header: "<avif/avif.h>".}

## Returns a pointer to a YUV or alpha plane.
proc avifImagePlane*(image: ptr avifImage; channel: cint): ptr uint8 {.
  importc, header: "<avif/avif.h>".}

## Returns row stride in bytes for a YUV or alpha plane.
proc avifImagePlaneRowBytes*(image: ptr avifImage; channel: cint): uint32 {.
  importc, header: "<avif/avif.h>".}

## Returns plane width in samples for a YUV or alpha plane.
proc avifImagePlaneWidth*(image: ptr avifImage; channel: cint): uint32 {.
  importc, header: "<avif/avif.h>".}

## Initializes RGB image defaults from an associated `avifImage`.
proc avifRGBImageSetDefaults*(rgb: ptr avifRGBImage; image: ptr avifImage) {.
  importc, header: "<avif/avif.h>".}

## Returns bytes per RGB pixel for the RGB image descriptor.
proc avifRGBImagePixelSize*(rgb: ptr avifRGBImage): uint32 {.
  importc, header: "<avif/avif.h>".}

## Allocates RGB pixel storage according to `avifRGBImage` fields.
proc avifRGBImageAllocatePixels*(rgb: ptr avifRGBImage): avifResult {.
  importc, header: "<avif/avif.h>".}

## Frees RGB pixel storage allocated by `avifRGBImageAllocatePixels`.
proc avifRGBImageFreePixels*(rgb: ptr avifRGBImage) {.
  importc, header: "<avif/avif.h>".}

## Converts caller-provided RGB pixels into image YUV planes.
proc avifImageRGBToYUV*(image: ptr avifImage; rgb: ptr avifRGBImage): avifResult {.
  importc, header: "<avif/avif.h>".}

## Converts image YUV planes into caller-provided or libavif-allocated RGB pixels.
proc avifImageYUVToRGB*(image: ptr avifImage; rgb: ptr avifRGBImage): avifResult {.
  importc, header: "<avif/avif.h>".}

## Allocates a decoder handle.
proc avifDecoderCreate*(): ptr avifDecoder {.importc, header: "<avif/avif.h>".}

## Destroys a decoder handle.
proc avifDecoderDestroy*(decoder: ptr avifDecoder) {.importc, header: "<avif/avif.h>".}

## Decodes from a previously configured decoder IO source into an image.
proc avifDecoderRead*(decoder: ptr avifDecoder; image: ptr avifImage): avifResult {.
  importc, header: "<avif/avif.h>".}

## Decodes a complete AVIF byte buffer into an image.
proc avifDecoderReadMemory*(decoder: ptr avifDecoder; image: ptr avifImage;
                            data: ptr uint8; size: csize_t): avifResult {.
  importc, header: "<avif/avif.h>".}

## Decodes an AVIF file into an image.
proc avifDecoderReadFile*(decoder: ptr avifDecoder; image: ptr avifImage;
                          filename: cstring): avifResult {.
  importc, header: "<avif/avif.h>".}

## Selects which AVIF source kind the decoder should read.
proc avifDecoderSetSource*(decoder: ptr avifDecoder;
                           source: avifDecoderSource): avifResult {.
  importc, header: "<avif/avif.h>".}

## Sets a memory buffer as decoder IO input.
proc avifDecoderSetIOMemory*(decoder: ptr avifDecoder; data: ptr uint8;
                             size: csize_t): avifResult {.
  importc, header: "<avif/avif.h>".}

## Sets a file path as decoder IO input.
proc avifDecoderSetIOFile*(decoder: ptr avifDecoder; filename: cstring): avifResult {.
  importc, header: "<avif/avif.h>".}

## Parses decoder input metadata without necessarily decoding pixels.
proc avifDecoderParse*(decoder: ptr avifDecoder): avifResult {.
  importc, header: "<avif/avif.h>".}

## Decodes the next image/frame from a parsed decoder input.
proc avifDecoderNextImage*(decoder: ptr avifDecoder): avifResult {.
  importc, header: "<avif/avif.h>".}

## Decodes a specific image/frame from a parsed decoder input.
proc avifDecoderNthImage*(decoder: ptr avifDecoder; frameIndex: uint32): avifResult {.
  importc, header: "<avif/avif.h>".}

## Resets a decoder to parse/decode again.
proc avifDecoderReset*(decoder: ptr avifDecoder): avifResult {.
  importc, header: "<avif/avif.h>".}

## Allocates an encoder handle.
proc avifEncoderCreate*(): ptr avifEncoder {.importc, header: "<avif/avif.h>".}

## Destroys an encoder handle.
proc avifEncoderDestroy*(encoder: ptr avifEncoder) {.importc, header: "<avif/avif.h>".}

## Encodes a single AVIF image into `avifRWData`.
proc avifEncoderWrite*(encoder: ptr avifEncoder; image: ptr avifImage;
                       output: ptr avifRWData): avifResult {.
  importc, header: "<avif/avif.h>".}

## Adds an image to an advanced encoder sequence.
proc avifEncoderAddImage*(encoder: ptr avifEncoder; image: ptr avifImage;
                          durationInTimescales: uint64;
                          addImageFlags: avifAddImageFlags): avifResult {.
  importc, header: "<avif/avif.h>".}

## Finishes an advanced encode and writes bytes into `avifRWData`.
proc avifEncoderFinish*(encoder: ptr avifEncoder;
                        output: ptr avifRWData): avifResult {.
  importc, header: "<avif/avif.h>".}

## Sets a codec-specific encoder option by key/value string.
proc avifEncoderSetCodecSpecificOption*(encoder: ptr avifEncoder;
                                         key, value: cstring): avifResult {.
  importc, header: "<avif/avif.h>".}
