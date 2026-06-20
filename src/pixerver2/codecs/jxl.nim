## Raw libjxl bindings.
##
## This module exposes selected public C APIs from the vendored JPEG XL
## libraries. It keeps libjxl's event-driven decoder and streaming encoder
## surface intact: callers manage decoder events, output buffers, frame
## settings, and optional thread runners directly.
##
## `JxlDecoder`, `JxlEncoder`, and thread-runner handles must be destroyed with
## their matching libjxl destroy functions. Encoding writes into caller-owned
## output buffers through `JxlEncoderProcessOutput`.
##
## The binding links the static libjxl, libjxl_dec, libjxl_threads, libjxl_cms,
## Brotli, and Highway archives under `build/vendor/libjxl`. Run `make codecs`
## before importing this module in a fresh checkout; JPEG XL also needs the
## generated export headers under `build/vendor/libjxl/lib/include`.

import std/os
import pixerver2/rawimage

const
  PixerverRoot = currentSourcePath().parentDir().parentDir().parentDir().parentDir()
  JxlInclude = PixerverRoot / "vendor/libjxl/lib/include"
  JxlGeneratedInclude = PixerverRoot / "build/vendor/libjxl/lib/include"
  JxlBuild = PixerverRoot / "build/vendor/libjxl"

{.passC: "-I" & JxlInclude.}
{.passC: "-I" & JxlGeneratedInclude.}
{.passL: JxlBuild / "lib/libjxl_dec.a".}
{.passL: JxlBuild / "lib/libjxl.a".}
{.passL: JxlBuild / "lib/libjxl_threads.a".}
{.passL: JxlBuild / "lib/libjxl_cms.a".}
{.passL: JxlBuild / "third_party/brotli/libbrotlidec.a".}
{.passL: JxlBuild / "third_party/brotli/libbrotlienc.a".}
{.passL: JxlBuild / "third_party/brotli/libbrotlicommon.a".}
{.passL: JxlBuild / "third_party/highway/libhwy.a".}
when defined(macosx):
  {.passL: "-lc++".}
elif defined(linux):
  {.passL: "-lstdc++ -lm -pthread".}

type
  ## JPEG XL boolean value. The C API uses `int`, not Nim `bool`.
  JXL_BOOL* = cint

  ## Return code used by JPEG XL parallel runner callbacks.
  JxlParallelRetCode* = cint

  ## Opaque decoder handle allocated by `JxlDecoderCreate`.
  JxlDecoder* {.importc: "JxlDecoder", header: "<jxl/decode.h>",
                incompleteStruct.} = object
  ## Opaque encoder handle allocated by `JxlEncoderCreate`.
  JxlEncoder* {.importc: "JxlEncoder", header: "<jxl/encode.h>",
                incompleteStruct.} = object
  ## Opaque per-frame encoder settings handle.
  JxlEncoderFrameSettings* {.importc: "JxlEncoderFrameSettings",
                             header: "<jxl/encode.h>", incompleteStruct.} = object
  ## Optional allocator hooks for libjxl object creation.
  JxlMemoryManager* {.importc: "JxlMemoryManager", header: "<jxl/memory_manager.h>",
                      incompleteStruct.} = object
  ## Public color encoding descriptor; bound opaquely for now.
  JxlColorEncoding* {.importc: "JxlColorEncoding", header: "<jxl/color_encoding.h>",
                      incompleteStruct.} = object

  ## Pixel channel sample types used in input/output buffers.
  JxlDataType* {.size: sizeof(cint).} = enum
    JXL_TYPE_FLOAT = 0
    JXL_TYPE_UINT8 = 2
    JXL_TYPE_UINT16 = 3
    JXL_TYPE_FLOAT16 = 5

  ## Endianness for multi-byte pixel sample types.
  JxlEndianness* {.size: sizeof(cint).} = enum
    JXL_NATIVE_ENDIAN = 0
    JXL_LITTLE_ENDIAN = 1
    JXL_BIG_ENDIAN = 2

  ## Interleaved pixel buffer descriptor used by decoder and encoder APIs.
  JxlPixelFormat* {.importc: "JxlPixelFormat", header: "<jxl/types.h>".} = object
    num_channels*: uint32
    data_type*: JxlDataType
    endianness*: JxlEndianness
    align*: csize_t

  ## Decoder/encoder bit depth interpretation mode.
  JxlBitDepthType* {.size: sizeof(cint).} = enum
    JXL_BIT_DEPTH_FROM_PIXEL_FORMAT = 0
    JXL_BIT_DEPTH_FROM_CODESTREAM = 1
    JXL_BIT_DEPTH_CUSTOM = 2

  ## Bit depth descriptor for image output/input interpretation.
  JxlBitDepth* {.importc: "JxlBitDepth", header: "<jxl/types.h>".} = object
    `type`*: JxlBitDepthType
    bits_per_sample*: uint32
    exponent_bits_per_sample*: uint32

  ## File signature classification returned by `JxlSignatureCheck`.
  JxlSignature* {.size: sizeof(cint).} = enum
    JXL_SIG_NOT_ENOUGH_BYTES = 0
    JXL_SIG_INVALID = 1
    JXL_SIG_CODESTREAM = 2
    JXL_SIG_CONTAINER = 3

  ## Decoder status and event values returned by `JxlDecoderProcessInput`.
  JxlDecoderStatus* {.size: sizeof(cint).} = enum
    JXL_DEC_SUCCESS = 0
    JXL_DEC_ERROR = 1
    JXL_DEC_NEED_MORE_INPUT = 2
    JXL_DEC_NEED_PREVIEW_OUT_BUFFER = 3
    JXL_DEC_NEED_IMAGE_OUT_BUFFER = 5
    JXL_DEC_JPEG_NEED_MORE_OUTPUT = 6
    JXL_DEC_BOX_NEED_MORE_OUTPUT = 7
    JXL_DEC_BASIC_INFO = 0x40
    JXL_DEC_COLOR_ENCODING = 0x100
    JXL_DEC_PREVIEW_IMAGE = 0x200
    JXL_DEC_FRAME = 0x400
    JXL_DEC_FULL_IMAGE = 0x1000
    JXL_DEC_JPEG_RECONSTRUCTION = 0x2000
    JXL_DEC_BOX = 0x4000
    JXL_DEC_FRAME_PROGRESSION = 0x8000
    JXL_DEC_BOX_COMPLETE = 0x10000

  ## Encoder status values returned by streaming encoder APIs.
  JxlEncoderStatus* {.size: sizeof(cint).} = enum
    JXL_ENC_SUCCESS = 0
    JXL_ENC_ERROR = 1
    JXL_ENC_NEED_MORE_OUTPUT = 2

  ## Detailed encoder error values available after `JXL_ENC_ERROR`.
  JxlEncoderError* {.size: sizeof(cint).} = enum
    JXL_ENC_ERR_OK = 0
    JXL_ENC_ERR_GENERIC = 1
    JXL_ENC_ERR_OOM = 2
    JXL_ENC_ERR_JBRD = 3
    JXL_ENC_ERR_BAD_INPUT = 4
    JXL_ENC_ERR_NOT_SUPPORTED = 0x80
    JXL_ENC_ERR_API_USAGE = 0x81

  ## EXIF-compatible orientation values.
  JxlOrientation* {.size: sizeof(cint).} = enum
    JXL_ORIENT_IDENTITY = 1
    JXL_ORIENT_FLIP_HORIZONTAL = 2
    JXL_ORIENT_ROTATE_180 = 3
    JXL_ORIENT_FLIP_VERTICAL = 4
    JXL_ORIENT_TRANSPOSE = 5
    JXL_ORIENT_ROTATE_90_CW = 6
    JXL_ORIENT_ANTI_TRANSPOSE = 7
    JXL_ORIENT_ROTATE_90_CCW = 8

  ## Extra channel kinds such as alpha, depth, or spot color.
  JxlExtraChannelType* {.size: sizeof(cint).} = enum
    JXL_CHANNEL_ALPHA = 0
    JXL_CHANNEL_DEPTH
    JXL_CHANNEL_SPOT_COLOR
    JXL_CHANNEL_SELECTION_MASK
    JXL_CHANNEL_BLACK
    JXL_CHANNEL_CFA
    JXL_CHANNEL_THERMAL
    JXL_CHANNEL_RESERVED0
    JXL_CHANNEL_RESERVED1
    JXL_CHANNEL_RESERVED2
    JXL_CHANNEL_RESERVED3
    JXL_CHANNEL_RESERVED4
    JXL_CHANNEL_RESERVED5
    JXL_CHANNEL_RESERVED6
    JXL_CHANNEL_RESERVED7
    JXL_CHANNEL_UNKNOWN
    JXL_CHANNEL_OPTIONAL

  ## Preview dimensions embedded in `JxlBasicInfo`.
  JxlPreviewHeader* {.importc: "JxlPreviewHeader",
                      header: "<jxl/codestream_header.h>".} = object
    xsize*: uint32
    ysize*: uint32

  ## Global animation timing metadata embedded in `JxlBasicInfo`.
  JxlAnimationHeader* {.importc: "JxlAnimationHeader",
                        header: "<jxl/codestream_header.h>".} = object
    tps_numerator*: uint32
    tps_denominator*: uint32
    num_loops*: uint32
    have_timecodes*: JXL_BOOL

  ## Public JPEG XL basic image metadata.
  JxlBasicInfo* {.importc: "JxlBasicInfo",
                  header: "<jxl/codestream_header.h>".} = object
    have_container*: JXL_BOOL
    xsize*: uint32
    ysize*: uint32
    bits_per_sample*: uint32
    exponent_bits_per_sample*: uint32
    intensity_target*: cfloat
    min_nits*: cfloat
    relative_to_max_display*: JXL_BOOL
    linear_below*: cfloat
    uses_original_profile*: JXL_BOOL
    have_preview*: JXL_BOOL
    have_animation*: JXL_BOOL
    orientation*: JxlOrientation
    num_color_channels*: uint32
    num_extra_channels*: uint32
    alpha_bits*: uint32
    alpha_exponent_bits*: uint32
    alpha_premultiplied*: JXL_BOOL
    preview*: JxlPreviewHeader
    animation*: JxlAnimationHeader
    intrinsic_xsize*: uint32
    intrinsic_ysize*: uint32
    padding*: array[100, uint8]

  ## Parallel runner initialization callback type.
  JxlParallelRunInit* = proc(jpegxlOpaque: pointer; numThreads: csize_t): JxlParallelRetCode {.
    cdecl.}

  ## Parallel runner work-item callback type.
  JxlParallelRunFunction* = proc(jpegxlOpaque: pointer; value: uint32;
                                 threadId: csize_t) {.cdecl.}

  ## Parallel runner callback type accepted by decoder and encoder APIs.
  JxlParallelRunner* = proc(runnerOpaque, jpegxlOpaque: pointer;
                            init: JxlParallelRunInit;
                            run: JxlParallelRunFunction;
                            startRange, endRange: uint32): JxlParallelRetCode {.cdecl.}

  JxlRawImageBuffer* = object
    ## Caller-owned `RawImage` memory described in the shape libjxl expects.
    ##
    ## Pass `pixelFormat.addr`, `data`, and `size` to APIs such as
    ## `JxlDecoderSetImageOutBuffer` or `JxlEncoderAddImageFrame`.
    pixelFormat*: JxlPixelFormat
    data*: pointer
    size*: csize_t

const
  ## JPEG XL true value for `JXL_BOOL`.
  JXL_TRUE* = 1

  ## JPEG XL false value for `JXL_BOOL`.
  JXL_FALSE* = 0

proc toJxlDataType*(format: PixelFormat): JxlDataType =
  ## Converts a pixerver raw pixel format into libjxl's channel data type.
  case format
  of rgba8:
    JXL_TYPE_UINT8
  of rgba16:
    JXL_TYPE_UINT16
  of rgbaF16:
    JXL_TYPE_FLOAT16

proc toJxlAlign*(width: int; format: PixelFormat; stride: int): csize_t =
  ## Converts a raw image stride into libjxl's row alignment field.
  ##
  ## libjxl does not take an explicit row stride. Instead, it derives row
  ## stride by rounding the packed row size up to a multiple of
  ## `JxlPixelFormat.align`. For tightly packed rows we use 0, which libjxl
  ## treats as no extra alignment. For padded rows, using `stride` as the
  ## alignment makes libjxl's computed row stride equal our `RawImage.stride`.
  let packedStride = minStride(width, format)
  if stride < packedStride:
    raise newException(ValueError, "image stride is smaller than packed row size")
  if stride == packedStride:
    0.csize_t
  else:
    stride.csize_t

proc toJxlPixelFormat*(image: RawImage): JxlPixelFormat =
  ## Builds the `JxlPixelFormat` descriptor for a `RawImage`.
  ##
  ## The descriptor uses 4 interleaved RGBA channels and native endian ordering
  ## for multi-byte formats, matching `RawImage`'s in-memory convention.
  if not image.isValid():
    raise newException(ValueError, "invalid raw image buffer")
  JxlPixelFormat(
    num_channels: 4,
    data_type: toJxlDataType(image.format),
    endianness: JXL_NATIVE_ENDIAN,
    align: toJxlAlign(image.width, image.format, image.stride)
  )

proc toJxlBuffer*(image: var RawImage): JxlRawImageBuffer =
  ## Returns mutable `RawImage` storage in the form libjxl accepts.
  ##
  ## Use this for decoder output buffers. The returned pointer is borrowed from
  ## `image.data`; keep the `RawImage` alive and do not resize its data while
  ## libjxl may write into it.
  if not image.isValid():
    raise newException(ValueError, "invalid raw image buffer")
  let dataPtr =
    if image.data.len == 0:
      nil
    else:
      cast[pointer](addr image.data[0])
  JxlRawImageBuffer(
    pixelFormat: toJxlPixelFormat(image),
    data: dataPtr,
    size: image.expectedBufferLen().csize_t
  )

proc toJxlConstBuffer*(image: RawImage): JxlRawImageBuffer =
  ## Returns read-only `RawImage` storage in the form libjxl accepts.
  ##
  ## Use this for encoder input buffers. The C type is still `void*` in this
  ## helper object, but callers should treat the returned pointer as borrowed
  ## read-only memory.
  if not image.isValid():
    raise newException(ValueError, "invalid raw image buffer")
  let dataPtr =
    if image.data.len == 0:
      nil
    else:
      cast[pointer](unsafeAddr image.data[0])
  JxlRawImageBuffer(
    pixelFormat: toJxlPixelFormat(image),
    data: dataPtr,
    size: image.expectedBufferLen().csize_t
  )

## Returns libjxl decoder version as libjxl's packed integer format.
proc JxlDecoderVersion*(): uint32 {.importc, header: "<jxl/decode.h>".}

## Returns libjxl encoder version as libjxl's packed integer format.
proc JxlEncoderVersion*(): uint32 {.importc, header: "<jxl/encode.h>".}

## Classifies a byte prefix as JPEG XL codestream, container, invalid, or short.
proc JxlSignatureCheck*(buf: ptr uint8; len: csize_t): JxlSignature {.
  importc, header: "<jxl/decode.h>".}

## Allocates a decoder. Pass nil for the default memory manager.
proc JxlDecoderCreate*(memoryManager: ptr JxlMemoryManager): ptr JxlDecoder {.
  importc, header: "<jxl/decode.h>".}

## Resets a decoder while keeping its memory manager.
proc JxlDecoderReset*(dec: ptr JxlDecoder) {.importc, header: "<jxl/decode.h>".}

## Destroys a decoder allocated by `JxlDecoderCreate`.
proc JxlDecoderDestroy*(dec: ptr JxlDecoder) {.importc, header: "<jxl/decode.h>".}

## Subscribes to decoder events such as basic info and full image completion.
proc JxlDecoderSubscribeEvents*(dec: ptr JxlDecoder; eventsWanted: cint): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Provides caller-owned input bytes to the decoder.
proc JxlDecoderSetInput*(dec: ptr JxlDecoder; data: ptr uint8;
                         size: csize_t): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Releases decoder input and returns the number of unconsumed bytes.
proc JxlDecoderReleaseInput*(dec: ptr JxlDecoder): csize_t {.
  importc, header: "<jxl/decode.h>".}

## Marks the current input stream as complete.
proc JxlDecoderCloseInput*(dec: ptr JxlDecoder) {.importc, header: "<jxl/decode.h>".}

## Advances the decoder and returns a status/event.
proc JxlDecoderProcessInput*(dec: ptr JxlDecoder): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Reads basic image metadata after the decoder reports `JXL_DEC_BASIC_INFO`.
proc JxlDecoderGetBasicInfo*(dec: ptr JxlDecoder;
                             info: ptr JxlBasicInfo): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Computes required output buffer size for the requested pixel format.
proc JxlDecoderImageOutBufferSize*(dec: ptr JxlDecoder;
                                   format: ptr JxlPixelFormat;
                                   size: ptr csize_t): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Sets caller-owned image output storage for decoded pixels.
proc JxlDecoderSetImageOutBuffer*(dec: ptr JxlDecoder;
                                  format: ptr JxlPixelFormat;
                                  buffer: pointer;
                                  size: csize_t): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Overrides output bit depth interpretation for decoded pixels.
proc JxlDecoderSetImageOutBitDepth*(dec: ptr JxlDecoder;
                                    bitDepth: ptr JxlBitDepth): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Installs a custom or libjxl-provided parallel runner on the decoder.
proc JxlDecoderSetParallelRunner*(dec: ptr JxlDecoder;
                                  parallelRunner: JxlParallelRunner;
                                  parallelRunnerOpaque: pointer): JxlDecoderStatus {.
  importc, header: "<jxl/decode.h>".}

## Allocates an encoder. Pass nil for the default memory manager.
proc JxlEncoderCreate*(memoryManager: ptr JxlMemoryManager): ptr JxlEncoder {.
  importc, header: "<jxl/encode.h>".}

## Resets an encoder while keeping its memory manager.
proc JxlEncoderReset*(enc: ptr JxlEncoder) {.importc, header: "<jxl/encode.h>".}

## Destroys an encoder allocated by `JxlEncoderCreate`.
proc JxlEncoderDestroy*(enc: ptr JxlEncoder) {.importc, header: "<jxl/encode.h>".}

## Writes encoded bytes into caller-owned output space and advances `nextOut`.
proc JxlEncoderProcessOutput*(enc: ptr JxlEncoder; nextOut: ptr ptr uint8;
                              availOut: ptr csize_t): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Initializes `JxlBasicInfo` with libjxl defaults before caller edits fields.
proc JxlEncoderInitBasicInfo*(info: ptr JxlBasicInfo) {.
  importc, header: "<jxl/encode.h>".}

## Sets basic image metadata on the encoder.
proc JxlEncoderSetBasicInfo*(enc: ptr JxlEncoder;
                             info: ptr JxlBasicInfo): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Creates per-frame encoder settings, optionally based on another settings object.
proc JxlEncoderFrameSettingsCreate*(enc: ptr JxlEncoder;
                                    source: ptr JxlEncoderFrameSettings):
                                    ptr JxlEncoderFrameSettings {.
  importc, header: "<jxl/encode.h>".}

## Sets lossy distance for frames using these settings.
proc JxlEncoderSetFrameDistance*(frameSettings: ptr JxlEncoderFrameSettings;
                                 distance: cfloat): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Enables or disables lossless frame encoding for these settings.
proc JxlEncoderSetFrameLossless*(frameSettings: ptr JxlEncoderFrameSettings;
                                 lossless: JXL_BOOL): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Adds one raw pixel frame to the encoder.
proc JxlEncoderAddImageFrame*(frameSettings: ptr JxlEncoderFrameSettings;
                              pixelFormat: ptr JxlPixelFormat;
                              buffer: pointer;
                              size: csize_t): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Signals that no more frames will be added.
proc JxlEncoderCloseFrames*(enc: ptr JxlEncoder) {.importc, header: "<jxl/encode.h>".}

## Signals that no more frame or box input will be added.
proc JxlEncoderCloseInput*(enc: ptr JxlEncoder) {.importc, header: "<jxl/encode.h>".}

## Enables or disables the JPEG XL container format for encoder output.
proc JxlEncoderUseContainer*(enc: ptr JxlEncoder; useContainer: JXL_BOOL): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Sets JPEG XL codestream level.
proc JxlEncoderSetCodestreamLevel*(enc: ptr JxlEncoder; level: cint): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Installs a custom or libjxl-provided parallel runner on the encoder.
proc JxlEncoderSetParallelRunner*(enc: ptr JxlEncoder;
                                  parallelRunner: JxlParallelRunner;
                                  parallelRunnerOpaque: pointer): JxlEncoderStatus {.
  importc, header: "<jxl/encode.h>".}

## Returns the detailed encoder error after `JXL_ENC_ERROR`.
proc JxlEncoderGetError*(enc: ptr JxlEncoder): JxlEncoderError {.
  importc, header: "<jxl/encode.h>".}

## libjxl's default thread-parallel runner callback.
proc JxlThreadParallelRunner*(runnerOpaque, jpegxlOpaque: pointer;
                              init: JxlParallelRunInit;
                              run: JxlParallelRunFunction;
                              startRange, endRange: uint32): JxlParallelRetCode {.
  importc, header: "<jxl/thread_parallel_runner.h>".}

## Creates an opaque thread-runner state object.
proc JxlThreadParallelRunnerCreate*(memoryManager: ptr JxlMemoryManager;
                                    numWorkerThreads: csize_t): pointer {.
  importc, header: "<jxl/thread_parallel_runner.h>".}

## Destroys state created by `JxlThreadParallelRunnerCreate`.
proc JxlThreadParallelRunnerDestroy*(runnerOpaque: pointer) {.
  importc, header: "<jxl/thread_parallel_runner.h>".}

## Returns libjxl's recommended worker count for the current system.
proc JxlThreadParallelRunnerDefaultNumWorkerThreads*(): csize_t {.
  importc, header: "<jxl/thread_parallel_runner.h>".}
