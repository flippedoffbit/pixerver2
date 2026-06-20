## Shared static link pragma for vendored SharpYUV.
##
## libwebp builds SharpYUV as a separate static archive, and libavif can also
## reference it through its RGB/YUV conversion path. Keeping the `passL` here
## lets WebP and AVIF bindings share one link directive when both modules are
## imported by the same Nim compilation unit.

import std/os

const
  PixerverRoot = currentSourcePath().parentDir().parentDir().parentDir().parentDir().parentDir()
  WebPBuild = PixerverRoot / "build/vendor/libwebp"

{.passL: WebPBuild / "libsharpyuv.a".}
