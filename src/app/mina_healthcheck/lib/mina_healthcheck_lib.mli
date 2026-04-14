(** Healthcheck logic for querying a Mina daemon's health.

    This library provides functions that query a Mina daemon via
    {!Mina_graphql_client} and evaluate health criteria (sync status,
    peer count, chain length).  It is used by the [mina-healthcheck]
    CLI binary and can be reused by any OCaml code that needs to
    check daemon health programmatically.

    Data types ({!Mina_graphql_client.Types.daemon_status},
    {!Mina_graphql_client.Types.readiness}, etc.) are serializable
    to JSON via [ppx_deriving_yojson]. *)

open Async

(** {1 CLI-specific JSON output types}

    These types are used only for JSON output formatting in the CLI.
    They wrap or augment the data from {!Mina_graphql_client.Types}
    with healthcheck-specific fields like [healthy] or [timed_out]. *)

type error_response = { healthy : bool; error : string } [@@deriving yojson]

type sync_status_response = { healthy : bool; sync_status : string }
[@@deriving yojson]

type peer_count_response = { healthy : bool; peer_count : int; min_peers : int }
[@@deriving yojson]

type chain_length_response =
  { healthy : bool
  ; blockchain_length : int option
  ; highest_block_length_received : int option
  }
[@@deriving yojson]

(** {1 Health check functions}

    Each function queries the daemon at [node_uri] and returns
    a typed result via [Deferred.Or_error.t].  Connection failures
    and GraphQL errors are propagated as [Error]. *)

(** Query the daemon's sync status.
    Returns the {!Sync_status.t} variant (e.g. [`Synced], [`Bootstrap]). *)
val get_sync_status :
  logger:Logger.t -> Uri.t -> Sync_status.t Deferred.Or_error.t

(** Get comprehensive daemon status: sync state, chain heights, uptime,
    commit hash, and connected peers. *)
val get_daemon_status :
     logger:Logger.t
  -> Uri.t
  -> Mina_graphql_client.Types.daemon_status Deferred.Or_error.t

(** Check whether peer count meets or exceeds [min_peers].
    Returns [(healthy, actual_peer_count)]. *)
val check_peer_count :
  logger:Logger.t -> Uri.t -> min_peers:int -> (bool * int) Deferred.Or_error.t

(** Check whether the local chain length matches the highest block
    length received from peers.
    Returns [(healthy, blockchain_length, highest_received)]. *)
val check_chain_length :
     logger:Logger.t
  -> Uri.t
  -> (bool * int option * int option) Deferred.Or_error.t

(** Combined readiness check: synced AND peers above threshold AND
    chain length matches highest received. *)
val check_readiness :
     logger:Logger.t
  -> Uri.t
  -> min_peers:int
  -> Mina_graphql_client.Types.readiness Deferred.Or_error.t

(** Collect human-readable problem descriptions from a readiness result.
    Returns an empty list when the node is fully ready. *)
val readiness_problems :
  min_peers:int -> Mina_graphql_client.Types.readiness -> string list

(** Wait until the daemon's GraphQL endpoint responds to a sync status
    query (regardless of the actual status).  Useful for waiting for
    daemon startup before running further checks.

    Returns [Ok sync_status] on first successful response, or [Error]
    on timeout. *)
val wait_for_graphql :
     logger:Logger.t
  -> Uri.t
  -> timeout:int
  -> interval:int
  -> Sync_status.t Deferred.Or_error.t

(** Block until the node passes all readiness checks or [timeout]
    seconds elapse.  Polls every [interval] seconds.  Progress is
    printed to stderr.

    Returns [Ok readiness] when ready, or [Error] on timeout. *)
val wait_for_ready :
     logger:Logger.t
  -> Uri.t
  -> min_peers:int
  -> timeout:int
  -> interval:int
  -> Mina_graphql_client.Types.readiness Deferred.Or_error.t
