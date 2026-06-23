## Raw Nim bindings for the vendored image codec libraries.
##
## This module only re-exports the per-library C surfaces. It intentionally
## does not introduce a unified codec abstraction.
##
## Import this when a caller wants all vendored codec symbols available:
##
##   import pixerver2/codecs
##
## Import `pixerver2/codecs/webp`, `pixerver2/codecs/avif`,
## `pixerver2/codecs/jxl`, or `pixerver2/codecs/heif` directly when only one
## codec surface is needed.
## These bindings expect the static libraries under `build/vendor`, which are
## produced by `make codecs`.

import pixerver2/codecs/[avif, heif, jxl, webp]

export avif, heif, jxl, webp
