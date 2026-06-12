import asynchttpserver, asyncdispatch, tables

type
  # ---------------------------------------------------------------------------
  # Errors

  FormSizeError* = object of CatchableError
    ## Raised when a form/upload body exceeds the caller-supplied size limit.

  # ---------------------------------------------------------------------------
  # File uploads

  UploadedFile* = object
    fieldName*:   string
    filename*:    string
    contentType*: string
    size*:        int    # byte length of data
    data*:        string # raw bytes (in-memory)

  FormData* = object
    fields*: Table[string, seq[string]]
    files*:  Table[string, seq[UploadedFile]]

  # ---------------------------------------------------------------------------
  # Context

  # Forward-declare so HandlerFn/MiddlewareFn can reference it.
  Context* = ref ContextObj

  HandlerFn*    = proc(ctx: Context): Future[void] {.gcsafe.}
  MiddlewareFn* = proc(ctx: Context): Future[void] {.gcsafe.}

  ContextObj* = object
    req*:          Request
    params*:       Table[string, string]    # path params  :id
    query*:        Table[string, string]    # ?key=val
    extras*:       Table[string, string]    # simple string k/v for middleware
    values*:       Table[string, RootRef]   # typed k/v — Go context.WithValue style
    formData*:     FormData
    responded*:    bool
    # internal middleware chain
    chain*:        seq[MiddlewareFn]
    chainIdx*:     int
    finalHandler*: HandlerFn

  # ---------------------------------------------------------------------------
  # Routing

  Route* = object
    meth*:        HttpMethod
    pattern*:     string
    handler*:     HandlerFn
    middlewares*: seq[MiddlewareFn]
