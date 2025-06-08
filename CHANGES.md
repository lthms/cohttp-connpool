# 0.2 (unreleased)

## `cohttp-connpool-eio`

*   Fixes `HEAD` requests from attempting to read a non-existent body before
    returning the connection to the pool. This prevents potential hangs and
    aligns behavior with `Cohttp_eio.Client.head`.
*   **Breaking change** Drops the `path` argument from the `warm` function,
    which now focuses solely on pre-populating the connection pool with
    established connections.

## `cohttp-connpool-lwt-unix`

* Mirrors the implementation of `cohttp-connpool-eio` for the `lwt-unix`
  backend.

# 0.1 (2025-05-31)

*   Manages and reuses previously established TCP connections.
*   Supports HTTPS connections.
*   Provides convenience functions for common HTTP methods (`GET`, `POST`,
    etc.).
*   Enables pre-populating the connection pool with active connections.
