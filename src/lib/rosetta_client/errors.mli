(** Rosetta-friendly formatting for HTTP errors and transport exceptions.

    These helpers produce short, human-readable strings that are safe to
    splat into a JSON [error] field or print on stderr.  They MUST NOT
    leak raw OCaml exception syntax (e.g. [(Unix_error ...)]) or dump
    multi-kilobyte HTTP bodies verbatim.  An exception carrying a plain
    message keeps it; a constructor is reported as a bare failure. *)

(** [format_http_body ~url ~status ~body] renders a non-2xx HTTP
    response as a short diagnostic like
    ["HTTP 500 from http://host/network/status: Network doesn't exist"].
    If
    [body] is a Rosetta error envelope ({"code":_,"message":_,...}), the
    [message] field is used; otherwise the body is included, truncated
    to a fixed cap. *)
val format_http_body : url:Uri.t -> status:int -> body:string -> string

(** [format_invalid_json ~url ~body] renders a 2xx response whose body
    is not JSON, with the body collapsed to one line and truncated to
    the same cap as {!format_http_body}. *)
val format_invalid_json : url:Uri.t -> body:string -> string

(** [format_exn ~url e] renders a transport exception (typically from
    Cohttp_async or Async_unix) as a short diagnostic like
    ["connection refused to http://localhost:9999"].  No raw OCaml
    exception syntax leaks through: an errno becomes prose, an
    exception whose sexp is a bare atom contributes that atom, and a
    constructor contributes nothing but the fact that the request
    failed. *)
val format_exn : url:Uri.t -> exn -> string
