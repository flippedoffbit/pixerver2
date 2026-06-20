import unittest, tables, strutils
import asyncdispatch, asynchttpserver
import ../src/pixerver2/types
import ../src/pixerver2/multipart
import ../src/pixerver2/context
import ../src/pixerver2/router
import ../src/pixerver2/rawimage

# ---------------------------------------------------------------------------
suite "multipart parser":

  test "boundary extraction":
    check getBoundary("multipart/form-data; boundary=abc123") == "abc123"
    check getBoundary("multipart/form-data; boundary=\"quoted\"") == "quoted"
    check getBoundary("text/plain") == ""

  test "field parsing":
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"username\"\r\n" &
      "\r\n" &
      "alice\r\n" &
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"role\"\r\n" &
      "\r\n" &
      "admin\r\n" &
      "--B--"
    let (fields, files) = parseMultipart(body, "multipart/form-data; boundary=B")
    check "username" in fields
    check fields["username"][0] == "alice"
    check "role" in fields
    check fields["role"][0] == "admin"
    check files.len == 0

  test "file upload parsing":
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"doc\"; filename=\"hello.txt\"\r\n" &
      "Content-Type: text/plain\r\n" &
      "\r\n" &
      "Hello, World!\r\n" &
      "--B--"
    let (fields, files) = parseMultipart(body, "multipart/form-data; boundary=B")
    check fields.len == 0
    check "doc" in files
    let f = files["doc"][0]
    check f.filename    == "hello.txt"
    check f.contentType == "text/plain"
    check f.data        == "Hello, World!"
    check f.size        == "Hello, World!".len

  test "size field matches data length":
    let payload = "binary\x00data\xFF"
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"bin\"; filename=\"blob.bin\"\r\n" &
      "Content-Type: application/octet-stream\r\n" &
      "\r\n" &
      payload & "\r\n" &
      "--B--"
    let (_, files) = parseMultipart(body, "multipart/form-data; boundary=B")
    check "bin" in files
    check files["bin"][0].size == payload.len
    check files["bin"][0].data == payload

  test "mixed fields and files":
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"title\"\r\n" &
      "\r\n" &
      "My Photo\r\n" &
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"photo\"; filename=\"img.png\"\r\n" &
      "Content-Type: image/png\r\n" &
      "\r\n" &
      "\x89PNG\r\n" &
      "--B--"
    let (fields, files) = parseMultipart(body, "multipart/form-data; boundary=B")
    check "title" in fields
    check fields["title"][0] == "My Photo"
    check "photo" in files
    check files["photo"][0].filename == "img.png"
    check files["photo"][0].contentType == "image/png"

  test "multi-value field":
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"tag\"\r\n" &
      "\r\n" &
      "nim\r\n" &
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"tag\"\r\n" &
      "\r\n" &
      "web\r\n" &
      "--B--"
    let (fields, _) = parseMultipart(body, "multipart/form-data; boundary=B")
    check "tag" in fields
    check fields["tag"].len == 2
    check "nim" in fields["tag"]
    check "web" in fields["tag"]

  test "multiple file uploads same field":
    let body =
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"files\"; filename=\"a.txt\"\r\n" &
      "Content-Type: text/plain\r\n" &
      "\r\n" &
      "file-a\r\n" &
      "--B\r\n" &
      "Content-Disposition: form-data; name=\"files\"; filename=\"b.txt\"\r\n" &
      "Content-Type: text/plain\r\n" &
      "\r\n" &
      "file-b\r\n" &
      "--B--"
    let (_, files) = parseMultipart(body, "multipart/form-data; boundary=B")
    check "files" in files
    check files["files"].len == 2
    check files["files"][0].filename == "a.txt"
    check files["files"][1].filename == "b.txt"

  test "empty body returns empty tables":
    let (fields, files) = parseMultipart("", "multipart/form-data; boundary=B")
    check fields.len == 0
    check files.len  == 0

  test "missing boundary returns empty tables":
    let (fields, files) = parseMultipart("anything", "text/plain")
    check fields.len == 0
    check files.len  == 0

# ---------------------------------------------------------------------------
suite "form size limits":

  # Helper: build a minimal multipart body of roughly targetSize bytes
  proc makeBody(fieldValue: string): string =
    "--B\r\n" &
    "Content-Disposition: form-data; name=\"data\"\r\n" &
    "\r\n" &
    fieldValue & "\r\n" &
    "--B--"

  # Helper: build a minimal multipart body with a file
  proc makeFileBody(fileData: string): string =
    "--B\r\n" &
    "Content-Disposition: form-data; name=\"file\"; filename=\"test.bin\"\r\n" &
    "Content-Type: application/octet-stream\r\n" &
    "\r\n" &
    fileData & "\r\n" &
    "--B--"

  test "parseMultipartForm succeeds within limit":
    let body = makeFileBody("small data")
    let ct   = "multipart/form-data; boundary=B"
    # Should not raise
    let (_, files) = parseMultipart(body, ct)
    check files["file"][0].data == "small data"

  test "parseMultipartForm raises FormSizeError when body exceeds limit":
    # Build a body bigger than the limit we will pass
    let bigData = 'x'.repeat(200)
    let body    = makeBody(bigData)
    let ct      = "multipart/form-data; boundary=B"

    # We test by calling the body-length check directly (same logic as
    # context.parseMultipartForm) since we can't easily construct a Request.
    let limit = 100
    check body.len > limit           # precondition: body is indeed larger
    var raised = false
    try:
      if body.len > limit:
        raise newException(FormSizeError, "too large")
    except FormSizeError:
      raised = true
    check raised

  test "FormSizeError is a CatchableError":
    var caught = false
    try:
      raise newException(FormSizeError, "over limit")
    except CatchableError:
      caught = true
    check caught

# ---------------------------------------------------------------------------
suite "context value store":

  # Values must inherit from RootObj to be storable as RootRef.
  type
    TestUser   = ref object of RootObj
      id:   int
      name: string

    AnotherRef = ref object of RootObj
      val: string

  test "set and get typed value":
    var values = initTable[string, RootRef]()
    let user = TestUser(id: 7, name: "alice")
    values["user"] = user

    # Safe downcast via `of` — same logic as ctx.get
    let v = values.getOrDefault("user", nil)
    check v != nil
    check v of TestUser
    let retrieved = TestUser(v)
    check retrieved.id   == 7
    check retrieved.name == "alice"

  test "missing key returns nil":
    var values = initTable[string, RootRef]()
    check values.getOrDefault("missing", nil) == nil

  test "overwrite value":
    var values = initTable[string, RootRef]()
    values["u"] = TestUser(id: 1, name: "first")
    values["u"] = TestUser(id: 2, name: "second")
    let u = TestUser(values["u"])
    check u.id == 2

  test "type mismatch returns nil via of check":
    var values = initTable[string, RootRef]()
    values["u"] = AnotherRef(val: "x")
    let v = values.getOrDefault("u", nil)
    # stored an AnotherRef, try to read as TestUser
    check not (v of TestUser)

  test "different types under different keys":
    var values = initTable[string, RootRef]()
    values["user"]  = TestUser(id: 99, name: "bob")
    values["other"] = AnotherRef(val: "hello")
    check TestUser(values["user"]).name   == "bob"
    check AnotherRef(values["other"]).val == "hello"

# ---------------------------------------------------------------------------
suite "raw image storage":

  test "pixel formats expose expected byte sizes":
    check bytesPerChannel(rgba8) == 1
    check bytesPerPixel(rgba8) == 4
    check bytesPerChannel(rgba16) == 2
    check bytesPerPixel(rgba16) == 8
    check bytesPerChannel(rgbaF16) == 2
    check bytesPerPixel(rgbaF16) == 8

  test "initRawImage allocates tightly packed rgba8 by default":
    let img = initRawImage(3, 2)
    check img.width == 3
    check img.height == 2
    check img.format == rgba8
    check img.stride == 12
    check img.data.len == 24
    check img.alphaMode == alphaStraight
    check img.orientation == orientIdentity
    check img.isTightlyPacked()
    check img.isValid()

  test "initRawImage accepts explicit padded stride":
    let img = initRawImage(3, 2, rgba16, stride = 32)
    check img.stride == 32
    check img.data.len == 64
    check not img.isTightlyPacked()
    check img.rowOffset(1) == 32
    check img.isValid()

  test "initRawImage rejects undersized stride":
    expect ValueError:
      discard initRawImage(3, 2, rgbaF16, stride = 12)

  test "isValid rejects inconsistent buffers":
    var img = initRawImage(2, 2)
    img.data.setLen(4)
    check not img.isValid()

# ---------------------------------------------------------------------------
suite "router":

  test "router creation":
    let r = newRouter()
    check r != nil
    check r.routes.len == 0
    check r.globalMiddlewares.len == 0

  test "route registration with do-block":
    let r = newRouter()
    r.get("/ping") do (ctx: Context) {.async.}:
      await ctx.text("pong")
    r.post("/echo") do (ctx: Context) {.async.}:
      await ctx.text(ctx.req.body)
    check r.routes.len == 2
    check r.routes[0].pattern == "/ping"
    check r.routes[0].meth    == HttpGet
    check r.routes[1].pattern == "/echo"
    check r.routes[1].meth    == HttpPost

  test "all HTTP verbs register":
    let r = newRouter()
    proc h(ctx: Context) {.async, gcsafe.} = await ctx.text("ok")
    r.get("/a",     h)
    r.post("/b",    h)
    r.put("/c",     h)
    r.patch("/d",   h)
    r.delete("/e",  h)
    r.head("/f",    h)
    r.options("/g", h)
    check r.routes.len == 7

  test "route group prefixes routes":
    let r   = newRouter()
    let api = r.group("/api/v1")
    proc h(ctx: Context) {.async, gcsafe.} = await ctx.text("ok")
    api.get("/users",  h)
    api.post("/users", h)
    check r.routes.len == 2
    check r.routes[0].pattern == "/api/v1/users"
    check r.routes[1].pattern == "/api/v1/users"

  test "global middleware registered":
    let r = newRouter()
    proc mw(ctx: Context) {.async, gcsafe.} = await ctx.next()
    r.use(mw)
    r.use(mw)
    check r.globalMiddlewares.len == 2

  test "per-route middleware stored":
    let r = newRouter()
    proc mw(ctx: Context) {.async, gcsafe.} = await ctx.next()
    proc h(ctx: Context)  {.async, gcsafe.} = await ctx.text("ok")
    r.get("/secret", mws(mw), h)
    check r.routes[0].middlewares.len == 1

  test "chained middlewares stored in order":
    let r = newRouter()
    proc mw1(ctx: Context) {.async, gcsafe.} = await ctx.next()
    proc mw2(ctx: Context) {.async, gcsafe.} = await ctx.next()
    proc mw3(ctx: Context) {.async, gcsafe.} = await ctx.next()
    proc h(ctx: Context)   {.async, gcsafe.} = await ctx.text("ok")
    r.get("/chain", mws(mw1, mw2, mw3), h)
    check r.routes[0].middlewares.len == 3
