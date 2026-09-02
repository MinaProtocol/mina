(** Thin HTTP wrapper around Cohttp_async for talking to a Rosetta
    server.

    A value of type {!t} bundles a base URI with the
    [network_identifier] to splice into outgoing request bodies.  The
    identifier and the timeout default to the shared values in
    {!Defaults}; override them via the optional arguments to
    {!create}. *)

type t

(** [create ~base_uri ?blockchain ?network ?timeout ()] builds a client.
    Defaults: {!Defaults.blockchain}, {!Defaults.network} and
    {!Defaults.http_timeout}. *)
val create :
     base_uri:Uri.t
  -> ?blockchain:string
  -> ?network:string
  -> ?timeout:float
  -> unit
  -> t

(** The network_identifier injected into every request body that needs
    one. *)
val network_identifier : t -> Rosetta_models.Network_identifier.t

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
