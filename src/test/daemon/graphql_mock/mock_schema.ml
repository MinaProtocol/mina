(** Composes the mock GraphQL schema.

    Mirrors the shape of [Mina_graphql.schema] — same field names,
    same nullability, parallel resolvers — but reads from the threaded
    [Mock_context.t] (persona) instead of the daemon's runtime.

    See README.md for the rationale on a parallel schema vs. reuse. *)

open Graphql_async
open Schema

(* ---------- Queries ---------- *)

let daemon_status =
  io_field "daemonStatus" ~doc:"Get running daemon status (mock)"
    ~args:Arg.[]
    ~typ:(non_null Mock_types.daemon_status)
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return (Ok persona.Persona.daemon) )

let sync_status =
  io_field "syncStatus" ~doc:"Network sync status (mock)"
    ~args:Arg.[]
    ~typ:(non_null Mock_types.sync_status_typ)
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return
        (Ok (Mock_types.parse_sync_status persona.Persona.daemon.sync_status))
      )

let version =
  io_field "version" ~doc:"The version of the node (mock)"
    ~args:Arg.[]
    ~typ:string
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return (Ok (Some persona.Persona.daemon.version)) )

let time_offset =
  io_field "timeOffset"
    ~doc:"The time offset in seconds used to convert real time to slots (mock)"
    ~args:Arg.[]
    ~typ:(non_null int)
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return (Ok persona.Persona.daemon.time_offset) )

let account =
  io_field "account" ~doc:"Find any account via a public key and token id (mock)"
    ~typ:Mock_types.account
    ~args:
      Arg.
        [ arg "publicKey" ~typ:(non_null Mock_types.public_key_arg)
            ~doc:"Public key of account"
        ; arg "token" ~typ:Mock_types.token_id_arg
            ~doc:"Token id of account (defaults to MINA token)"
        ]
    ~resolve:(fun { ctx = persona; _ } () public_key _token ->
      Async.return
        (Ok
           (Mock_types.mock_account_of_persona persona ~public_key) ) )

(* The mock pretends every token is owned by the block-producer account. *)
let token_owner =
  io_field "tokenOwner"
    ~doc:"Find the account that owns a given token (mock: always the block producer)"
    ~typ:Mock_types.account
    ~args:
      Arg.
        [ arg "tokenId" ~typ:(non_null Mock_types.token_id_arg)
            ~doc:"Token id of token"
        ]
    ~resolve:(fun { ctx = persona; _ } () _token_id ->
      Async.return
        (Ok
           (Mock_types.mock_account_of_persona persona
              ~public_key:persona.Persona.daemon.block_producer_account ) ) )

let genesis_constants =
  io_field "genesisConstants"
    ~doc:"Constants used to determine genesis state (mock)"
    ~typ:(non_null Mock_types.genesis_constants)
    ~args:Arg.[]
    ~resolve:(fun _ () -> Async.return (Ok Mock_types.canned_genesis_constants))

(* Type annotations on these lists are intentionally absent; let the compiler
   unify each field's context with [Mock_context.t] from the resolvers. *)
let queries =
  [ sync_status
  ; daemon_status
  ; version
  ; time_offset
  ; account
  ; token_owner
  ; genesis_constants
  ]

(* ---------- Mutations ---------- *)

(* startFilteredLog — the simplest mutation in the real schema (no input
   object, no payload). Always returns true; the mock doesn't actually log. *)
let start_filtered_log =
  io_field "startFilteredLog"
    ~doc:
      "Start filtering and tracing the log of the daemon (mock: always succeeds)"
    ~typ:(non_null bool)
    ~args:
      Arg.[ arg "filter" ~typ:(non_null (list (non_null string))) ]
    ~resolve:(fun _ () _filter -> Async.return (Ok true))

let mutations = [ start_filtered_log ]

(* ---------- Subscriptions ---------- *)

let subscriptions = []

(* ---------- Schema ---------- *)

let schema = schema queries ~mutations ~subscriptions
