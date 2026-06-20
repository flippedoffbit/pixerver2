# AGENTS.md

Guidance for coding agents working in this repository.

## Project Overview

`pixerver2` is a Nim web server/router package. The public entry point is
`src/pixerver2.nim`, which re-exports the package modules and also contains a
demo server under `when isMainModule`.

Core modules live in `src/pixerver2/`:

- `server.nim`: server construction and request dispatch
- `router.nim`: route registration, groups, params, middleware chaining
- `context.nim`: request/response helpers, body/form parsing, context values
- `multipart.nim`: multipart parser and upload support
- `types.nim`: shared types and exceptions

Tests live in `tests/`.

## Build And Test

Use the project-local commands where possible:

- `nimble test` to run the test suite
- `nimble build` to build the package binary
- `nim c -r src/pixerver2.nim` to run the demo server locally
- `make codecs` to build vendored static codec libraries, if codec work needs it

The `vendor/` and `build/` directories can be large or generated. Avoid editing
vendored sources or generated build outputs unless the task explicitly requires
that.

## Coding Notes

- Keep Nim code idiomatic and compatible with the version declared in
  `pixerver2.nimble` (`nim >= 2.2.10`).
- Preserve the async style used by handlers and middleware:
  `proc ... {.async, gcsafe.}` where existing APIs require it.
- Context values are stored as `RootRef`; values intended for typed retrieval
  should be `ref object of RootObj`.
- Prefer existing helpers on `Context` for responses and request access
  (`json`, `text`, `html`, `badRequest`, `tooLarge`, `header`, `query`,
  `field`, `file`, and related helpers).
- Keep route and middleware behavior aligned with the demo in
  `src/pixerver2.nim`; it doubles as a usage example.
- For parser changes, add focused tests in `tests/test1.nim` or split tests only
  when a new file improves clarity.

## Repository Hygiene

- Do not commit generated binaries or build artifacts from `build/` or the root
  `pixerver2` binary unless explicitly requested.
- Do not run destructive cleanup commands without confirming intent.
- Before finishing a behavior change, run the narrow relevant tests first, then
  `nimble test` when feasible.
