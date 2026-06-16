(** Rosetta Data API: read-only endpoints.

    The raw endpoint functions POST to the appropriate path and return
    the decoded response as a [Yojson.Safe.t].  The client's
    [network_identifier] is injected automatically; callers pass in only
    the endpoint-specific payload.

    The [*_response] helpers decode selected endpoint responses through
    the generated Rosetta model Yojson bindings. *)

val network_list : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val network_list_response :
  Http.t -> Rosetta_models.Network_list_response.t Async.Deferred.Or_error.t

val network_status : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val network_status_response :
  Http.t -> Rosetta_models.Network_status_response.t Async.Deferred.Or_error.t

val network_options : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val network_options_response :
  Http.t -> Rosetta_models.Network_options_response.t Async.Deferred.Or_error.t

val block :
     Http.t
  -> ?index:int
  -> ?hash:string
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val account_balance :
     Http.t
  -> address:string
  -> ?token_id:string
  -> ?block_index:int
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val account_coins :
     Http.t
  -> address:string
  -> ?include_mempool:bool
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t

val mempool : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val mempool_transaction :
  Http.t -> tx_hash:string -> Yojson.Safe.t Async.Deferred.Or_error.t

val search_transactions :
     Http.t
  -> ?address:string
  -> ?tx_hash:string
  -> ?limit:int
  -> unit
  -> Yojson.Safe.t Async.Deferred.Or_error.t
