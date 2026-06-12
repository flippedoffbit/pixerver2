import std/[asynchttpserver, asyncdispatch, tables, strutils, uri, json]

import types
import multipart as mp

const
  DefaultMaxMemory* = 32 * 1024 * 1024
  DefaultMaxFormSize* = 10 * 1024 * 1024

# ---------------------------------------------------------------------------
# Tiny primitives

template headers(pairs: varargs[tuple[key, val: string]]): HttpHeaders =
  newHttpHeaders(@pairs)

template contentTypeHeader(value: string): HttpHeaders =
  headers(("Content-Type", value))

template dieIfTooLarge(body: string; limit: int; kind: string) =
  if limit > 0 and body.len > limit:
    raise newException(
      FormSizeError,
      kind & " body " & $body.len & "B exceeds limit " & $limit & "B"
    )

proc firstOrDefault*[T](xs: seq[T]; fallback: T): T =
  if xs.len == 0: fallback else: xs[0]

proc addMulti*[K, V](t: var Table[K, seq[V]]; key: K; val: V) =
  t.mgetOrPut(key, @[]).add val

iterator decodedPairs*(s: string): tuple[key, val: string] =
  for pair in s.split('&'):
    if pair.len == 0:
      continue

    let kv = pair.split('=', 1)

    yield (
      key: decodeUrl(kv[0]),
      val: if kv.len == 2: decodeUrl(kv[1]) else: ""
    )

# ---------------------------------------------------------------------------
# Construction

proc newContext*(req: Request): Context =
  Context(
    req: req,
    params: initTable[string, string](),
    query: initTable[string, string](),
    extras: initTable[string, string](),
    values: initTable[string, RootRef](),
    formData: FormData(
      fields: initTable[string, seq[string]](),
      files: initTable[string, seq[UploadedFile]]()
    ),
    responded: false,
    chainIdx: 0
  )

# ---------------------------------------------------------------------------
# Middleware chain

proc next*(ctx: Context) {.async, gcsafe.} =
  let idx = ctx.chainIdx
  inc ctx.chainIdx

  if idx < ctx.chain.len:
    await ctx.chain[idx](ctx)
  elif ctx.finalHandler != nil and not ctx.responded:
    await ctx.finalHandler(ctx)

# ---------------------------------------------------------------------------
# Typed context value store

proc set*(ctx: Context; key: string; val: RootRef) =
  ctx.values[key] = val

proc get*[T: ref RootObj](ctx: Context; key: string; _: typedesc[T]): T =
  let val = ctx.values.getOrDefault(key)

  if val != nil and val of T:
    T(val)
  else:
    nil

proc has*(ctx: Context; key: string): bool =
  key in ctx.values

# ---------------------------------------------------------------------------
# Request helpers

proc header*(ctx: Context; name: string): string =
  ctx.req.headers.getOrDefault(name.toLowerAscii())

proc contentType*(ctx: Context): string =
  ctx.header("content-type")

proc contentLength*(ctx: Context): int =
  let raw = ctx.header("content-length")

  try:
    if raw.len == 0:
      ctx.req.body.len
    else:
      parseInt(raw)
  except ValueError:
    ctx.req.body.len

proc parseQuery*(ctx: Context) =
  for key, val in decodedPairs(ctx.req.url.query):
    if key.len > 0:
      ctx.query[key] = val

# ---------------------------------------------------------------------------
# Body / form parsing

proc parseUrlEncoded*(ctx: Context; maxSize: int = DefaultMaxFormSize) =
  dieIfTooLarge(ctx.req.body, maxSize, "url-encoded")

  for key, val in decodedPairs(ctx.req.body):
    if key.len > 0:
      ctx.formData.fields.addMulti(key, val)

proc parseMultipartForm*(ctx: Context; maxMemory: int = DefaultMaxMemory) =
  dieIfTooLarge(ctx.req.body, maxMemory, "multipart")

  let (fields, files) = mp.parseMultipart(ctx.req.body, ctx.contentType())
  ctx.formData.fields = fields
  ctx.formData.files = files

proc parseForm*(ctx: Context; maxMemory: int = DefaultMaxMemory) =
  let kind = ctx.contentType().toLowerAscii()

  if "multipart/form-data" in kind:
    ctx.parseMultipartForm(maxMemory)
  elif "application/x-www-form-urlencoded" in kind:
    ctx.parseUrlEncoded(maxMemory)

proc bodyJson*(ctx: Context): JsonNode =
  parseJson(ctx.req.body)

# ---------------------------------------------------------------------------
# Accessors

template tableFirst(tableExpr, keyExpr, fallbackExpr: untyped): untyped =
  block:
    let xs = tableExpr.getOrDefault(keyExpr)
    xs.firstOrDefault(fallbackExpr)

proc field*(ctx: Context; name: string): string =
  tableFirst(ctx.formData.fields, name, "")

proc fieldAll*(ctx: Context; name: string): seq[string] =
  ctx.formData.fields.getOrDefault(name)

proc file*(ctx: Context; name: string): UploadedFile =
  tableFirst(ctx.formData.files, name, UploadedFile())

proc fileAll*(ctx: Context; name: string): seq[UploadedFile] =
  ctx.formData.files.getOrDefault(name)

proc hasFile*(ctx: Context; name: string): bool =
  ctx.formData.files.getOrDefault(name).len > 0

# ---------------------------------------------------------------------------
# Responses

proc send*(
  ctx: Context;
  status: HttpCode;
  body: string;
  headers: HttpHeaders = nil
) {.async.} =
  if ctx.responded:
    return

  ctx.responded = true
  await ctx.req.respond(status, body, headers)

template makeResponder(name, mime: untyped) =
  proc name*(ctx: Context; body: string; status: HttpCode = Http200) {.async.} =
    await ctx.send(status, body, contentTypeHeader(mime))

makeResponder text, "text/plain; charset=utf-8"
makeResponder html, "text/html; charset=utf-8"

proc json*(ctx: Context; data: JsonNode; status: HttpCode = Http200) {.async.} =
  await ctx.send(status, $data, contentTypeHeader("application/json"))

proc json*(ctx: Context; data: string; status: HttpCode = Http200) {.async.} =
  await ctx.send(status, data, contentTypeHeader("application/json"))

proc redirect*(
  ctx: Context;
  location: string;
  status: HttpCode = Http302
) {.async.} =
  await ctx.send(status, "", headers(("Location", location)))

template makeStatus(name, code, defaultMsg: untyped) =
  proc name*(ctx: Context; msg: string = defaultMsg) {.async.} =
    await ctx.text(msg, code)

makeStatus notFound, Http404, "Not Found"
makeStatus badRequest, Http400, "Bad Request"
makeStatus tooLarge, Http413, "Request Entity Too Large"
makeStatus internalError, Http500, "Internal Server Error"
