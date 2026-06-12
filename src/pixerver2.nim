

import asyncdispatch, asynchttpserver, json, strutils, tables
import pixerver2/server
import pixerver2/router
import pixerver2/context
import pixerver2/types
export server, router, context, types

# ---------------------------------------------------------------------------
when isMainModule:

  # ---- Typed context values (Go: context.WithValue) -----------------------
  #
  # Any ref object can be stored in ctx.values and retrieved type-safely.
  # Context values must be ref objects that inherit from RootObj so they can
  # be stored as RootRef and safely downcast via Nim's `of` operator.
  type
    User* = ref object of RootObj
      id*: int
      email*: string
      role*: string

  # ---- Middleware ----------------------------------------------------------

  proc loggerMw(ctx: Context) {.async, gcsafe.} =
    echo "[", ctx.req.reqMethod, "] ", ctx.req.url.path
    await ctx.next()

  proc authMw(ctx: Context) {.async, gcsafe.} =
    ## Validates token, then stores the User in the request context so
    ## downstream handlers can read it — same pattern as Go's chi/echo.
    let token = ctx.header("authorization")
    if not token.startsWith("Bearer "):
      await ctx.json(%*{"error": "missing or invalid Authorization header"}, Http401)
      return
    # In real life: verify JWT / DB lookup here.
    let user = User(id: 42, email: "alice@example.com", role: "admin")
    ctx.set("user", user) # store typed value in context
    await ctx.next()

  proc adminOnlyMw(ctx: Context) {.async, gcsafe.} =
    let user = ctx.get("user", User)
    if user == nil or user.role != "admin":
      await ctx.json(%*{"error": "Forbidden"}, Http403)
      return
    await ctx.next()

  # ---- Main ----------------------------------------------------------------

  proc main() {.async.} =

    # Server-level body size gate: any request with body > 100 MB is rejected
    # before routing with HTTP 413 — no handler code runs at all.
    let s = newServer(port = 8080, maxBodySize = 100 * 1024 * 1024)

    s.use(loggerMw) # global middleware

    # ---- Simple routes ------------------------------------------------------

    s.router.get("/") do (ctx: Context) {.async.}:
      await ctx.html("""
        <h1>pixerver2 demo</h1>
        <ul>
          <li>POST /upload   — multipart file upload (limit 10 MB per request)</li>
          <li>POST /upload/multi   — multiple files</li>
          <li>POST /form     — url-encoded form</li>
          <li>POST /api/data — JSON body</li>
          <li>GET  /me       — auth middleware + context value</li>
          <li>GET  /admin    — auth + role check (chained middlewares)</li>
          <li>GET  /users/:id</li>
          <li>GET  /search?q=&amp;limit=</li>
        </ul>""")

    s.router.get("/health") do (ctx: Context) {.async.}:
      await ctx.json(%*{"status": "ok"})

    # ---- Path params --------------------------------------------------------

    s.router.get("/users/:id") do (ctx: Context) {.async.}:
      await ctx.json(%*{"id": ctx.params["id"]})

    s.router.get("/search") do (ctx: Context) {.async.}:
      await ctx.json(%*{
        "q": ctx.query.getOrDefault("q", ""),
        "limit": ctx.query.getOrDefault("limit", "10")
      })


    s.router.post("/upload") do (ctx: Context) {.async.}:
      try:
        ctx.parseForm(maxMemory = 10 * 1024 * 1024) # 10 MB per-route limit
      except FormSizeError as e:
        await ctx.tooLarge("Upload too large: " & e.msg)
        return

      if not ctx.hasFile("file"):
        await ctx.badRequest("no file field named \"file\"")
        return

      let f = ctx.file("file")
      let desc = ctx.field("description")
      await ctx.json(%*{
        "description": desc,
        "filename": f.filename,
        "contentType": f.contentType,
        "size": f.size # bytes
      })

    # Multiple files in one request
    s.router.post("/upload/multi") do (ctx: Context) {.async.}:
      try:
        ctx.parseForm(maxMemory = 50 * 1024 * 1024) # 50 MB for batch
      except FormSizeError as e:
        await ctx.tooLarge(e.msg)
        return

      var arr = newJArray()
      for f in ctx.fileAll("files"):
        arr.add(%*{"filename": f.filename, "size": f.size,
                   "contentType": f.contentType})
      await ctx.json(%*{"count": arr.len, "files": arr})

    # ---- URL-encoded form ---------------------------------------------------

    s.router.post("/form") do (ctx: Context) {.async.}:
      try:
        ctx.parseForm(maxMemory = 1 * 1024 * 1024) # 1 MB for plain forms
      except FormSizeError as e:
        await ctx.tooLarge(e.msg)
        return
      await ctx.json(%*{
        "name": ctx.field("name"),
        "email": ctx.field("email"),
        "tags": ctx.fieldAll("tag")
      })

    # ---- JSON body ----------------------------------------------------------

    s.router.post("/api/data") do (ctx: Context) {.async.}:
      let data = ctx.bodyJson()
      await ctx.json(%*{"received": data})

    
    s.router.get("/me", mws(authMw)) do (ctx: Context) {.async.}:
      let user = ctx.get("user", User) # typed retrieval — no cast in user code
      await ctx.json(%*{"id": user.id, "email": user.email, "role": user.role})

  
    s.router.get("/admin", mws(authMw, adminOnlyMw)) do (
      ctx: Context) {.async.}:
      await ctx.json(%*{"message": "Welcome, admin!"})

    let v1 = s.router.group("/api/v1")
    v1.get("/ping") do (ctx: Context) {.async.}: await ctx.text("pong")
    v1.get("/items/:id") do (ctx: Context) {.async.}:
      await ctx.json(%*{"item": ctx.params["id"]})

    s.router.get("/static/*") do (ctx: Context) {.async.}:
      await ctx.text("static: " & ctx.params.getOrDefault("*", ""))

    s.router.notFoundHandler = proc(ctx: Context): Future[void] {.gcsafe.} =
      ctx.json(%*{"error": "Not Found", "path": ctx.req.url.path}, Http404)

    await s.start()

  waitFor main()
