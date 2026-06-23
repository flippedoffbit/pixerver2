## Raw libheif bindings plus first HEIF/HEIC decode helpers.
##
## The default link path points at a vendored static install prefix populated by
## `make codecs` or `make heif`:
##
##   build/vendor/heif-prefix/include
##   build/vendor/heif-prefix/lib
##
## That vendored build expects `vendor/libheif` and `vendor/libde265` to exist.
##
## Override paths at compile time if needed:
##
##   nim c -d:pixerverHeifInclude=/usr/include \
##         -d:pixerverHeifLib=/usr/lib ...
##
## HEIF can contain HEVC/HEIC, AVIF, JPEG, JPEG 2000, and other payloads
## depending on the libheif build and available plugins. This first helper path
## decodes the primary image to interleaved RGBA8 or RGBA16 `RawImage` storage.

import std/os
import pixerver2/rawimage

const
  PixerverRoot = currentSourcePath().parentDir().parentDir().parentDir().parentDir()
  DefaultHeifInclude = PixerverRoot / "build/vendor/heif-prefix/include"
  DefaultHeifLib = PixerverRoot / "build/vendor/heif-prefix/lib"

const
  HeifInclude* {.strdefine: "pixerverHeifInclude".} = DefaultHeifInclude
  HeifLib* {.strdefine: "pixerverHeifLib".} = DefaultHeifLib

{.passC: "-I" & HeifInclude.}
{.passC: "-DLIBHEIF_STATIC_BUILD -DLIBDE265_STATIC_BUILD".}
{.passL: HeifLib / "libheif.a".}
{.passL: HeifLib / "libde265.a".}
when defined(macosx):
  {.passL: "-lc++".}
elif defined(linux):
  {.passL: "-lstdc++ -ldl".}
when defined(posix):
  {.passL: "-lm -pthread".}

type
  heif_context* {.importc: "heif_context", header: "<libheif/heif.h>",
                  incompleteStruct.} = object
  heif_image_handle* {.importc: "heif_image_handle", header: "<libheif/heif.h>",
                       incompleteStruct.} = object
  heif_image* {.importc: "heif_image", header: "<libheif/heif.h>",
                incompleteStruct.} = object
  heif_reading_options* {.importc: "heif_reading_options",
                          header: "<libheif/heif.h>", incompleteStruct.} = object
  heif_decoding_options* {.importc: "heif_decoding_options",
                           header: "<libheif/heif.h>", incompleteStruct.} = object
  heif_init_params* {.importc: "heif_init_params", header: "<libheif/heif.h>",
                      incompleteStruct.} = object

  heif_error* {.importc: "heif_error", header: "<libheif/heif.h>".} = object
    ## libheif error value. `code == heif_error_Ok` means success.
    code*: cint
    subcode*: cint
    message*: cstring

  heif_colorspace* {.size: sizeof(cint).} = enum
    heif_colorspace_YCbCr = 0
    heif_colorspace_RGB = 1
    heif_colorspace_monochrome = 2
    heif_colorspace_nonvisual = 3
    heif_colorspace_undefined = 99

  heif_chroma* {.size: sizeof(cint).} = enum
    heif_chroma_monochrome = 0
    heif_chroma_420 = 1
    heif_chroma_422 = 2
    heif_chroma_444 = 3
    heif_chroma_interleaved_RGB = 10
    heif_chroma_interleaved_RGBA = 11
    heif_chroma_interleaved_RRGGBB_BE = 12
    heif_chroma_interleaved_RRGGBBAA_BE = 13
    heif_chroma_interleaved_RRGGBB_LE = 14
    heif_chroma_interleaved_RRGGBBAA_LE = 15
    heif_chroma_undefined = 99

  heif_channel* {.size: sizeof(cint).} = enum
    heif_channel_Y = 0
    heif_channel_Cb = 1
    heif_channel_Cr = 2
    heif_channel_R = 3
    heif_channel_G = 4
    heif_channel_B = 5
    heif_channel_Alpha = 6
    heif_channel_interleaved = 10
    heif_channel_filter_array = 11
    heif_channel_depth = 12
    heif_channel_disparity = 13

  heif_compression_format* {.size: sizeof(cint).} = enum
    heif_compression_undefined = 0
    heif_compression_HEVC = 1
    heif_compression_AVC = 2
    heif_compression_JPEG = 3
    heif_compression_AV1 = 4
    heif_compression_VVC = 5
    heif_compression_EVC = 6
    heif_compression_JPEG2000 = 7
    heif_compression_uncompressed = 8
    heif_compression_mask = 9
    heif_compression_HTJ2K = 10

const
  heif_error_Ok* = 0

proc heif_get_version*(): cstring {.importc, header: "<libheif/heif.h>".}
proc heif_get_version_number*(): uint32 {.importc, header: "<libheif/heif.h>".}
proc heif_init*(params: ptr heif_init_params): heif_error {.
  importc, header: "<libheif/heif.h>".}
proc heif_deinit*() {.importc, header: "<libheif/heif.h>".}

proc heif_context_alloc*(): ptr heif_context {.importc, header: "<libheif/heif.h>".}
proc heif_context_free*(ctx: ptr heif_context) {.importc, header: "<libheif/heif.h>".}
proc heif_context_read_from_file*(ctx: ptr heif_context; filename: cstring;
                                  options: ptr heif_reading_options): heif_error {.
  importc, header: "<libheif/heif.h>".}
proc heif_context_read_from_memory_without_copy*(ctx: ptr heif_context;
                                                 mem: pointer;
                                                 size: csize_t;
                                                 options: ptr heif_reading_options):
                                                 heif_error {.
  importc, header: "<libheif/heif.h>".}
proc heif_context_get_primary_image_handle*(ctx: ptr heif_context;
                                            handle: ptr ptr heif_image_handle):
                                            heif_error {.
  importc, header: "<libheif/heif.h>".}
proc heif_context_set_max_decoding_threads*(ctx: ptr heif_context; maxThreads: cint) {.
  importc, header: "<libheif/heif.h>".}

proc heif_have_decoder_for_format*(format: heif_compression_format): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_release*(handle: ptr heif_image_handle) {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_get_width*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_get_height*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_get_luma_bits_per_pixel*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_get_chroma_bits_per_pixel*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_has_alpha_channel*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_handle_is_premultiplied_alpha*(handle: ptr heif_image_handle): cint {.
  importc, header: "<libheif/heif.h>".}

proc heif_decode_image*(handle: ptr heif_image_handle;
                        outImage: ptr ptr heif_image;
                        colorspace: heif_colorspace;
                        chroma: heif_chroma;
                        options: ptr heif_decoding_options): heif_error {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_release*(image: ptr heif_image) {.importc, header: "<libheif/heif.h>".}
proc heif_image_get_primary_width*(image: ptr heif_image): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_get_primary_height*(image: ptr heif_image): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_get_bits_per_pixel_range*(image: ptr heif_image;
                                          channel: heif_channel): cint {.
  importc, header: "<libheif/heif.h>".}
proc heif_image_get_plane_readonly2*(image: ptr heif_image;
                                     channel: heif_channel;
                                     outStride: ptr csize_t): ptr uint8 {.
  importc, header: "<libheif/heif.h>".}

proc ok*(err: heif_error): bool =
  ## Returns true when a libheif call succeeded.
  err.code == heif_error_Ok

proc `$`*(err: heif_error): string =
  ## Formats a libheif error for exceptions/logging.
  let msg = if err.message == nil: "" else: $err.message
  "libheif error code=" & $err.code & " subcode=" & $err.subcode & " " & msg

proc raiseIfError(err: heif_error) =
  if not err.ok():
    raise newException(IOError, $err)

proc heifChromaForRawFormat(format: PixelFormat): heif_chroma =
  case format
  of rgba8:
    heif_chroma_interleaved_RGBA
  of rgba16:
    when defined(cpuEndianLittle):
      heif_chroma_interleaved_RRGGBBAA_LE
    else:
      heif_chroma_interleaved_RRGGBBAA_BE
  of rgbaF16:
    raise newException(ValueError, "libheif decode helper does not support rgbaF16")

proc copyHeifInterleavedPlane(image: ptr heif_image; dst: var RawImage) =
  var srcStride: csize_t
  let src = heif_image_get_plane_readonly2(
    image,
    heif_channel_interleaved,
    addr srcStride
  )
  if src == nil:
    raise newException(IOError, "libheif decoded image has no interleaved plane")

  let rowBytes = minStride(dst.width, dst.format)
  if srcStride < rowBytes.csize_t:
    raise newException(IOError, "libheif decoded row stride is smaller than expected")

  for y in 0 ..< dst.height:
    let srcRow = cast[pointer](cast[uint](src) + uint(y) * uint(srcStride))
    copyMem(addr dst.data[dst.rowOffset(y)], srcRow, rowBytes)

proc decodePrimaryImage(ctx: ptr heif_context; format: PixelFormat): RawImage =
  var handle: ptr heif_image_handle
  heif_context_get_primary_image_handle(ctx, addr handle).raiseIfError()
  if handle == nil:
    raise newException(IOError, "HEIF file has no primary image")
  try:
    let width = heif_image_handle_get_width(handle)
    let height = heif_image_handle_get_height(handle)
    if width <= 0 or height <= 0:
      raise newException(IOError, "HEIF primary image has invalid dimensions")

    var decoded: ptr heif_image
    heif_decode_image(
      handle,
      addr decoded,
      heif_colorspace_RGB,
      heifChromaForRawFormat(format),
      nil
    ).raiseIfError()
    if decoded == nil:
      raise newException(IOError, "libheif returned no decoded image")

    try:
      result = initRawImage(width, height, format)
      result.alphaMode =
        if heif_image_handle_has_alpha_channel(handle) == 0:
          alphaNone
        elif heif_image_handle_is_premultiplied_alpha(handle) != 0:
          alphaPremultiplied
        else:
          alphaStraight
      copyHeifInterleavedPlane(decoded, result)
    finally:
      heif_image_release(decoded)
  finally:
    heif_image_handle_release(handle)

proc decodeHeifPrimaryToRawImage*(
  data: openArray[uint8];
  format: PixelFormat = rgba8;
  maxThreads: int = 0
): RawImage =
  ## Decodes the primary HEIF/HEIC image from memory into `RawImage`.
  ##
  ## `format` may be `rgba8` or `rgba16`. Use `rgba16` for high-bit-depth/HDR
  ## preservation. The input memory is borrowed by libheif while the context is
  ## alive, so this proc keeps the context scoped to the decode.
  if data.len == 0:
    raise newException(ValueError, "HEIF input is empty")

  heif_init(nil).raiseIfError()
  try:
    let ctx = heif_context_alloc()
    if ctx == nil:
      raise newException(IOError, "could not allocate libheif context")
    try:
      heif_context_set_max_decoding_threads(ctx, maxThreads.cint)
      heif_context_read_from_memory_without_copy(
        ctx,
        cast[pointer](unsafeAddr data[0]),
        data.len.csize_t,
        nil
      ).raiseIfError()
      result = decodePrimaryImage(ctx, format)
    finally:
      heif_context_free(ctx)
  finally:
    heif_deinit()

proc decodeHeifPrimaryFileToRawImage*(
  filename: string;
  format: PixelFormat = rgba8;
  maxThreads: int = 0
): RawImage =
  ## Decodes the primary HEIF/HEIC image from a file path into `RawImage`.
  if filename.len == 0:
    raise newException(ValueError, "HEIF filename is empty")

  heif_init(nil).raiseIfError()
  try:
    let ctx = heif_context_alloc()
    if ctx == nil:
      raise newException(IOError, "could not allocate libheif context")
    try:
      heif_context_set_max_decoding_threads(ctx, maxThreads.cint)
      heif_context_read_from_file(ctx, filename.cstring, nil).raiseIfError()
      result = decodePrimaryImage(ctx, format)
    finally:
      heif_context_free(ctx)
  finally:
    heif_deinit()
