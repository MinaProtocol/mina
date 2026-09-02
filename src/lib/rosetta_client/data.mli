(** Rosetta Data API: read-only endpoints.

    Each function POSTs to the appropriate path and returns the parsed
    response as a [Yojson.Safe.t].  The client's [network_identifier] is
    injected automatically; callers pass in only the endpoint-specific
    payload.

    JSON rather than the generated model, because the caller that only
    prints the answer -- [rosetta-client] -- must show what the server
    actually sent, including fields the model does not know about and
    responses that do not validate.  A caller that wants to read fields
    instead pipes the same call through {!decode}:

    {[
      Data.network_status client
      |> Data.decode Rosetta_models.Network_status_response.of_yojson
    ]} *)

(** [decode of_yojson response] parses [response] through a generated
    Rosetta model's [of_yojson].  A response that does not match the
    schema becomes an error rather than an exception. *)
val decode :
     (Yojson.Safe.t -> ('a, string) Result.t)
  -> Yojson.Safe.t Async.Deferred.Or_error.t
  -> 'a Async.Deferred.Or_error.t

val network_list : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val network_status : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

val network_options : Http.t -> Yojson.Safe.t Async.Deferred.Or_error.t

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

(* /account/coins is absent for the same reason as /block/transaction:
   Mina's Rosetta does not implement it.  [Account.router] routes
   ["balance"] and answers 404 to everything else, and the coins model
   is a UTXO notion that an account-based chain has nothing to say
   about -- /network/options advertises [mempool_coins = false]. *)

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
