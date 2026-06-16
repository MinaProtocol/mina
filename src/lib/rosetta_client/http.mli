(** Thin HTTP wrapper around Cohttp_async for talking to a Rosetta
    server.

    A value of type {!t} bundles a base URI with the default
    [network_identifier] ({"blockchain": _, "network": _}) to splice
    into outgoing POST bodies.  The defaults for the identifier are
    [blockchain = "mina"] and [network = "testnet"] per the project's
    convention; override via optional arguments to {!create}. *)

type t

(** [create ~base_uri ?blockchain ?network ?timeout ()] builds a client.
    Defaults: [blockchain = "mina"], [network = "testnet"],
    [timeout = 5.0] seconds. *)
val create :
     base_uri:Uri.t
  -> ?blockchain:string
  -> ?network:string
  -> ?timeout:float
  -> unit
  -> t

val base_uri : t -> Uri.t

val blockchain : t -> string

val network : t -> string

val timeout : t -> float

(** The default network_identifier payload injected into request bodies
    that need one. *)
val network_identifier : t -> Yojson.Safe.t

(** [post_json t ~path ~body] POSTs [body] to [base_uri ^ path] with a
    JSON content type and [timeout] enforcement.  Non-2xx responses and
    decode failures are folded into the error channel via
    {!Errors.format_http_body} and {!Errors.format_exn}; the resulting
    strings never contain raw OCaml exception syntax. *)
val post_json :
     t
  -> path:string
  -> body:Yojson.Safe.t
  -> Yojson.Safe.t Async.Deferred.Or_error.t

(** GET variant of {!post_json}.  Rosetta endpoints are POST-only in
    practice, but this is useful for sidecar endpoints and tests. *)
val get_json : t -> path:string -> Yojson.Safe.t Async.Deferred.Or_error.t

(** Pretty-print (indented) a JSON value to a string. *)
val pretty : Yojson.Safe.t -> string

(** Compact-print a JSON value to a string. *)
val compact : Yojson.Safe.t -> string
