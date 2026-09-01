(** Rosetta-friendly formatting for HTTP errors and transport exceptions.

    These helpers produce short, human-readable strings that are safe to
    splat into a JSON [error] field or print on stderr.  They MUST NOT
    leak raw OCaml exception syntax (e.g. [(Unix_error ...)]) or dump
    multi-kilobyte HTTP bodies verbatim. *)

(** [format_http_body ~status ~body] renders a non-2xx HTTP response as
    a short diagnostic like ["HTTP 500: Network doesn't exist"]. If
    [body] is a Rosetta error envelope ({"code":_,"message":_,...}), the
    [message] field is used; otherwise the body is included truncated to
    [max_body_chars] characters. *)
val format_http_body : status:int -> body:string -> string

(** [format_exn ~url e] renders a transport exception (typically from
    Cohttp_async or Async_unix) as a short diagnostic like
    ["connection refused to http://localhost:9999"].  No raw OCaml
    exception syntax leaks through. *)
val format_exn : url:Uri.t -> exn -> string

(** Character cap used by [format_http_body] when falling back to the
    raw body.  Exposed so callers can reference the same bound in tests
    and documentation. *)
val max_body_chars : int
