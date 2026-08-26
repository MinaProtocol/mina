(** Rosetta Construction API wrappers.

    Every function builds the generated Rosetta request model for its
    endpoint (with [network_identifier] injected automatically), POSTs
    it, and returns the decoded response.  Arguments are the typed
    models rather than raw JSON, so a malformed payload is rejected
    while it is still being decoded from the caller's input instead of
    by the server.

    [metadata] and [options] stay [Yojson.Safe.t] because the Rosetta
    schema itself leaves those two fields free-form. *)

val derive :
     Http.t
  -> public_key:Rosetta_models.Public_key.t
  -> ?metadata:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val preprocess :
     Http.t
  -> operations:Rosetta_models.Operation.t list
  -> ?metadata:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val metadata :
     Http.t
  -> ?options:Yojson.Safe.t
  -> ?public_keys:Rosetta_models.Public_key.t list
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val payloads :
     Http.t
  -> operations:Rosetta_models.Operation.t list
  -> ?metadata:Yojson.Safe.t
  -> ?public_keys:Rosetta_models.Public_key.t list
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val parse :
     Http.t
  -> signed:bool
  -> transaction:string
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val combine :
     Http.t
  -> unsigned_transaction:string
  -> signatures:Rosetta_models.Signature.t list
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val hash :
  Http.t -> signed_transaction:string -> Yojson.Safe.t Async.Deferred.Or_error.t

val submit :
  Http.t -> signed_transaction:string -> Yojson.Safe.t Async.Deferred.Or_error.t
