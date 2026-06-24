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

    Every subcommand emits exactly one record of the corresponding
    response type so the shape is the same on success and failure.
    [healthy] is always present.  Optional fields are omitted from
    the JSON when [None] — so an error envelope is simply
    [{healthy: false, error: "..."}] without any [null] noise. *)

(** Response payload for [sync-status].
    [healthy = true] iff the daemon's sync status equals [SYNCED]. *)
type sync_status_response =
  { healthy : bool
  ; sync_status : string option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

(** Response payload for [daemon-status].  Mirrors
    {!Mina_graphql_client.Types.daemon_status} with [healthy] and an
    optional [error] field; data fields are omitted when unknown. *)
type daemon_status_response =
  { healthy : bool
  ; sync_status : Sync_status.t option [@default None]
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; uptime_secs : int option [@default None]
  ; state_hash : string option [@default None]
  ; commit_id : string option [@default None]
  ; peer_count : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

(** Response payload for [peer-count].
    [healthy = true] iff [peer_count >= min_peers]. *)
type peer_count_response =
  { healthy : bool
  ; peer_count : int option [@default None]
  ; min_peers : int
  ; error : string option [@default None]
  }
[@@deriving yojson]

(** Response payload for [chain-length].
    [healthy = true] iff both heights are known and equal. *)
type chain_length_response =
  { healthy : bool
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

(** Response payload for [ready] and [wait].  Mirrors
    {!Mina_graphql_client.Types.readiness} with [healthy] (= [ready])
    and an optional [error] field. *)
type readiness_response =
  { healthy : bool
  ; sync_status : Sync_status.t option [@default None]
  ; peer_count : int option [@default None]
  ; blockchain_length : int option [@default None]
  ; highest_block_length_received : int option [@default None]
  ; error : string option [@default None]
  }
[@@deriving yojson]

(** {1 Health check functions}

    Each function queries the daemon at [node_uri] and returns
    a typed result via [Deferred.Or_error.t].  Connection failures
    and GraphQL errors are propagated as [Error].

    For raw GraphQL queries (sync status, daemon status, readiness),
    call {!Mina_graphql_client.Client} functions directly — this module
    no longer re-exports them. *)

(** Check whether peer count meets or exceeds [min_peers].
    Returns [(healthy, actual_peer_count)].

    Optional [num_tries] / [retry_delay_sec] / [deadline] are forwarded
    to the underlying GraphQL retry loop.  CLI subcommands that report
    a one-shot answer pass [~num_tries:1] so a dead daemon yields a
    fast error instead of a 5-minute hang. *)
val check_peer_count :
     ?num_tries:int
  -> ?retry_delay_sec:float
  -> ?deadline:Core.Time.t
  -> logger:Logger.t
  -> Uri.t
  -> min_peers:int
  -> (bool * int) Deferred.Or_error.t

(** Check whether the local chain length matches the highest block
    length received from peers.
    Returns [(healthy, blockchain_length, highest_received)].

    See {!check_peer_count} for the optional retry-control parameters. *)
val check_chain_length :
     ?num_tries:int
  -> ?retry_delay_sec:float
  -> ?deadline:Core.Time.t
  -> logger:Logger.t
  -> Uri.t
  -> (bool * int option * int option) Deferred.Or_error.t

(** Collect human-readable problem descriptions from a readiness result.
    Returns an empty list when the node is fully ready. *)
val readiness_problems :
  min_peers:int -> Mina_graphql_client.Types.readiness -> string list

(** Wait until the daemon's GraphQL endpoint responds to a sync status
    query (regardless of the actual status).  Useful for waiting for
    daemon startup before running further checks.

    [~quiet] suppresses the per-tick progress lines written to stderr;
    pass [true] from JSON-mode CLI callers that need stderr to stay
    empty.

    Returns [Ok sync_status] on first successful response, or [Error]
    on timeout. *)
val wait_for_graphql :
     ?quiet:bool
  -> logger:Logger.t
  -> Uri.t
  -> timeout:int
  -> interval:int
  -> Sync_status.t Deferred.Or_error.t

(** Block until the node passes all readiness checks or [timeout]
    seconds elapse.  Polls every [interval] seconds.  Progress is
    printed to stderr unless [~quiet:true].

    Returns [Ok readiness] when ready, or [Error] on timeout. *)
val wait_for_ready :
     ?quiet:bool
  -> logger:Logger.t
  -> Uri.t
  -> min_peers:int
  -> timeout:int
  -> interval:int
  -> Mina_graphql_client.Types.readiness Deferred.Or_error.t
