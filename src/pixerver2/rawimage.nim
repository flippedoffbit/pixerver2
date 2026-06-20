## Canonical in-memory image storage used between codec-specific decoders and
## encoders.
##
## This is not a file format and it is not a codec abstraction. It is a simple
## raw RGBA pixel container plus enough color metadata to avoid flattening HDR
## or wide-gamut images too early.
##
## The default format is `rgba8`, which is the right path for most mass-media
## upload and serving work. `rgba16` and `rgbaF16` exist for high-bit-depth and
## HDR paths. `rgbaF32` is intentionally not included: it is too memory-heavy
## for normal server-side image handling.

type
  PixelFormat* = enum
    ## 8-bit unsigned integer RGBA, 4 bytes per pixel.
    rgba8
    ## 16-bit unsigned integer RGBA, 8 bytes per pixel.
    rgba16
    ## 16-bit floating point RGBA, 8 bytes per pixel.
    rgbaF16

  TransferCurve* = enum
    ## Transfer function is unknown or should be interpreted from ICC metadata.
    transferUnknown
    ## Standard nonlinear sRGB transfer.
    transferSRgb
    ## Linear light.
    transferLinear
    ## SMPTE ST 2084 perceptual quantizer, common for HDR10.
    transferPQ
    ## Hybrid log-gamma, common for broadcast HDR.
    transferHLG

  ColorPrimaries* = enum
    ## Color primaries are unknown or should be interpreted from ICC metadata.
    primariesUnknown
    ## BT.709/sRGB primaries.
    primariesSRgb
    ## Display P3 primaries.
    primariesDisplayP3
    ## BT.2020 primaries.
    primariesBT2020
    ## Custom primaries described externally, usually by ICC metadata.
    primariesCustom

  AlphaMode* = enum
    ## Image should be treated as fully opaque.
    alphaNone
    ## Alpha is stored as straight, unpremultiplied alpha.
    alphaStraight
    ## RGB channels are premultiplied by alpha.
    alphaPremultiplied

  ImageOrientation* = enum
    ## EXIF orientation value 1.
    orientIdentity = 1
    ## EXIF orientation value 2.
    orientFlipHorizontal = 2
    ## EXIF orientation value 3.
    orientRotate180 = 3
    ## EXIF orientation value 4.
    orientFlipVertical = 4
    ## EXIF orientation value 5.
    orientTranspose = 5
    ## EXIF orientation value 6.
    orientRotate90Cw = 6
    ## EXIF orientation value 7.
    orientAntiTranspose = 7
    ## EXIF orientation value 8.
    orientRotate90Ccw = 8

  RawImage* = object
    ## Width in pixels.
    width*: int
    ## Height in pixels.
    height*: int
    ## Bytes from one row start to the next. May be larger than tight packing.
    stride*: int
    ## Pixel storage format for `data`.
    format*: PixelFormat
    ## Raw row-major pixel bytes.
    ##
    ## All formats are RGBA channel order. For 16-bit formats, channel bytes
    ## are stored in native-endian C memory order because this is an in-memory
    ## container intended for codec interop, not stable serialization.
    data*: seq[uint8]

    ## ICC profile bytes when present. Empty means absent.
    iccProfile*: string
    ## Coarse transfer metadata for pipelines that do not inspect ICC.
    transfer*: TransferCurve
    ## Coarse primary metadata for pipelines that do not inspect ICC.
    primaries*: ColorPrimaries
    ## Alpha interpretation for the RGBA data.
    alphaMode*: AlphaMode
    ## Display orientation, using EXIF-compatible values.
    orientation*: ImageOrientation

proc bytesPerChannel*(format: PixelFormat): int =
  ## Returns the storage size of one channel for `format`.
  case format
  of rgba8:
    1
  of rgba16, rgbaF16:
    2

proc bytesPerPixel*(format: PixelFormat): int =
  ## Returns bytes per RGBA pixel for `format`.
  4 * bytesPerChannel(format)

proc minStride*(width: int; format: PixelFormat): int =
  ## Returns the minimum row stride for tightly packed RGBA rows.
  if width < 0:
    raise newException(ValueError, "image width cannot be negative")
  width * bytesPerPixel(format)

proc requiredBufferLen*(height, stride: int): int =
  ## Returns the byte length needed for `height` rows at `stride` bytes each.
  if height < 0:
    raise newException(ValueError, "image height cannot be negative")
  if stride < 0:
    raise newException(ValueError, "image stride cannot be negative")
  height * stride

proc initRawImage*(
  width, height: int;
  format: PixelFormat = rgba8;
  stride: int = 0
): RawImage =
  ## Allocates a raw RGBA image buffer.
  ##
  ## When `stride` is 0, rows are tightly packed. A non-zero stride must be at
  ## least `minStride(width, format)`.
  let packedStride = minStride(width, format)
  let actualStride =
    if stride == 0:
      packedStride
    else:
      if stride < packedStride:
        raise newException(ValueError, "image stride is smaller than packed row size")
      stride

  result = RawImage(
    width: width,
    height: height,
    stride: actualStride,
    format: format,
    data: newSeq[uint8](requiredBufferLen(height, actualStride)),
    transfer: transferUnknown,
    primaries: primariesUnknown,
    alphaMode: alphaStraight,
    orientation: orientIdentity
  )

proc tightBufferLen*(width, height: int; format: PixelFormat): int =
  ## Returns the byte length for tightly packed image storage.
  requiredBufferLen(height, minStride(width, format))

proc isTightlyPacked*(image: RawImage): bool =
  ## Returns true when `stride` equals the packed RGBA row size.
  image.stride == minStride(image.width, image.format)

proc expectedBufferLen*(image: RawImage): int =
  ## Returns the byte length implied by image dimensions and stride.
  requiredBufferLen(image.height, image.stride)

proc isValid*(image: RawImage): bool =
  ## Returns true when dimensions, stride, and data length are self-consistent.
  if image.width < 0 or image.height < 0 or image.stride < 0:
    return false
  if image.stride < minStride(image.width, image.format):
    return false
  image.data.len >= expectedBufferLen(image)

proc rowOffset*(image: RawImage; y: int): int =
  ## Returns the byte offset for row `y`.
  if y < 0 or y >= image.height:
    raise newException(IndexDefect, "image row out of range")
  y * image.stride
