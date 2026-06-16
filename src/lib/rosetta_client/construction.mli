(** Rosetta Construction API wrappers.

    Every function POSTs the given payload (with [network_identifier]
    injected automatically) to the corresponding endpoint and returns
    the decoded response. *)

val derive :
     Http.t
  -> public_key:Yojson.Safe.t
  -> ?metadata:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val preprocess :
     Http.t
  -> operations:Yojson.Safe.t
  -> ?metadata:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val metadata :
     Http.t
  -> options:Yojson.Safe.t
  -> ?public_keys:Yojson.Safe.t
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val payloads :
     Http.t
  -> operations:Yojson.Safe.t
  -> ?metadata:Yojson.Safe.t
  -> ?public_keys:Yojson.Safe.t
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
  -> signatures:Yojson.Safe.t
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val hash :
  Http.t -> signed_transaction:string -> Yojson.Safe.t Async.Deferred.Or_error.t

val submit :
  Http.t -> signed_transaction:string -> Yojson.Safe.t Async.Deferred.Or_error.t
