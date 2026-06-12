import std/[asynchttpserver, asyncdispatch, tables, strutils, macros]
import types
import context

type
  Router* = ref object
    routes*: seq[Route]
    globalMiddlewares*: seq[MiddlewareFn]
    notFoundHandler*: HandlerFn

  RouteGroup* = ref object
    router*: Router
    prefix*: string
    middlewares*: seq[MiddlewareFn]

# ---------------------------------------------------------------------------
# Defaults

proc defaultNotFound(ctx: Context) {.async, gcsafe.} =
  await ctx.notFound()

proc newRouter*(): Router =
  Router(
    routes: @[],
    globalMiddlewares: @[],
    notFoundHandler: defaultNotFound
  )

# ---------------------------------------------------------------------------
# Middleware helpers

proc use*(r: Router, mw: MiddlewareFn) =
  r.globalMiddlewares.add mw

macro mws*(fs: varargs[untyped]): untyped =
  let tmp = genSym(nskVar, "middlewares")
  var body = newStmtList()

  body.add quote do:
    var `tmp`: seq[MiddlewareFn] = @[]

  for f in fs:
    let mw = genSym(nskLet, "mw")
    body.add quote do:
      let `mw`: MiddlewareFn = `f`
      `tmp`.add `mw`

  body.add tmp

  result = newNimNode(nnkBlockExpr)
  result.add newEmptyNode()
  result.add body

# ---------------------------------------------------------------------------
# Path matching

proc captureParam(
  patternSeg, pathSeg: string;
  params: var Table[string, string]
): bool =
  if patternSeg.startsWith(':'):
    params[patternSeg[1 .. ^1]] = pathSeg
    true
  else:
    patternSeg == pathSeg

proc matchPath*(
  pattern, path: string;
  params: var Table[string, string]
): bool =
  if pattern == path:
    return true

  let
    patSegs = pattern.split('/')
    pathSegs = path.split('/')

  if patSegs.len == 0:
    return false

  if patSegs[^1] == "*":
    let fixedLen = patSegs.len - 1

    if pathSegs.len < fixedLen:
      return false

    for i in 0 ..< fixedLen:
      if not captureParam(patSegs[i], pathSegs[i], params):
        return false

    params["*"] =
      if pathSegs.len == fixedLen:
        ""
      else:
        pathSegs[fixedLen .. ^1].join("/")

    return true

  if patSegs.len != pathSegs.len:
    return false

  for i in 0 ..< patSegs.len:
    if not captureParam(patSegs[i], pathSegs[i], params):
      return false

  true

# ---------------------------------------------------------------------------
# Route registration

proc addRoute*(
  r: Router;
  meth: HttpMethod;
  pattern: string;
  handler: HandlerFn;
  middlewares: openArray[MiddlewareFn] = []
) =
  r.routes.add Route(
    meth: meth,
    pattern: pattern,
    handler: handler,
    middlewares: @middlewares
  )

proc group*(
  r: Router;
  prefix: string;
  middlewares: openArray[MiddlewareFn] = []
): RouteGroup =
  RouteGroup(
    router: r,
    prefix: prefix,
    middlewares: @middlewares
  )

template defineVerb(name, meth: untyped) =
  proc name*(
    r: Router;
    path: string;
    handler: HandlerFn;
    middlewares: openArray[MiddlewareFn] = []
  ) =
    r.addRoute(meth, path, handler, middlewares)

  proc name*(
    r: Router;
    path: string;
    middlewares: openArray[MiddlewareFn];
    handler: HandlerFn
  ) =
    r.addRoute(meth, path, handler, middlewares)

  proc name*(
    g: RouteGroup;
    path: string;
    handler: HandlerFn;
    middlewares: openArray[MiddlewareFn] = []
  ) =
    g.router.addRoute(meth, g.prefix & path, handler, g.middlewares & @middlewares)

  proc name*(
    g: RouteGroup;
    path: string;
    middlewares: openArray[MiddlewareFn];
    handler: HandlerFn
  ) =
    g.router.addRoute(meth, g.prefix & path, handler, g.middlewares & @middlewares)

defineVerb get, HttpGet
defineVerb post, HttpPost
defineVerb put, HttpPut
defineVerb patch, HttpPatch
defineVerb delete, HttpDelete
defineVerb head, HttpHead
defineVerb options, HttpOptions

# ---------------------------------------------------------------------------
# Dispatch

proc dispatch*(r: Router, req: Request) {.async, gcsafe.} =
  for route in r.routes:
    if route.meth != req.reqMethod:
      continue

    var params = initTable[string, string]()

    if not matchPath(route.pattern, req.url.path, params):
      continue

    let ctx = newContext(req)

    ctx.params = params
    ctx.parseQuery()
    ctx.chain = r.globalMiddlewares & route.middlewares
    ctx.finalHandler = route.handler

    await ctx.next()
    return

  let ctx = newContext(req)
  ctx.parseQuery()
  await r.notFoundHandler(ctx)
