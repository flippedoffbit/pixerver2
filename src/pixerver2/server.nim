import asynchttpserver, asyncdispatch
import router
import types
import context

export router, types, context

type
  Server* = ref object
    router*:      Router
    port*:        Port
    host*:        string
    ## Body size gate applied before any handler runs (0 = unlimited).
    ## Requests exceeding this limit receive 413 immediately.
    ## Set this at the server level; use parseMultipartForm(maxMemory) for
    ## per-route control over multipart/upload parsing.
    maxBodySize*: int

proc newServer*(port: int = 8080, host: string = "0.0.0.0",
               maxBodySize: int = 0): Server =
  Server(router: newRouter(), port: Port(port), host: host,
         maxBodySize: maxBodySize)

proc use*(s: Server, mw: MiddlewareFn) =
  s.router.use(mw)

proc start*(s: Server) {.async.} =
  let httpServer = newAsyncHttpServer()
  let r          = s.router
  let maxBody    = s.maxBodySize
  proc cb(req: Request): Future[void] {.async, gcsafe.} =
    # Server-level body size gate — runs before routing.
    if maxBody > 0 and req.body.len > maxBody:
      await req.respond(Http413, "Request body too large",
                        newHttpHeaders([("Content-Type", "text/plain; charset=utf-8")]))
      return
    await r.dispatch(req)
  echo "pixerver2 listening on http://", s.host, ":", s.port.int
  await httpServer.serve(s.port, cb)
