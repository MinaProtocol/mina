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

(* sendPayment — flagship demonstrative mutation. Builds a mock_user_command
   from the SendPaymentInput, returns it via SendPaymentPayload. The synthetic
   hash is fixed per persona (persona.syntheticTxHashes.sendPayment) so docs
   examples always reference the same hash. *)
let send_payment =
  io_field "sendPayment"
    ~doc:"Send a payment (mock: returns a canned, deterministic synthetic tx)"
    ~typ:(non_null Mock_types.send_payment_payload)
    ~args:
      Arg.
        [ arg "signature" ~typ:Mock_types.signature_input
            ~doc:"If a signature is provided, this transaction is considered signed and will be broadcasted to the network without requiring a private key"
        ; arg "input" ~typ:(non_null Mock_types.send_payment_input)
        ]
    ~resolve:(fun { ctx = persona; _ } () _signature input ->
      let synthetic_hash =
        match persona.Persona.synthetic_tx_hashes with
        | `Assoc pairs -> (
            match List.assoc_opt "sendPayment" pairs with
            | Some (`String s) ->
                s
            | _ ->
                "5JmoOcksyntheticxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" )
        | _ ->
            "5JmoOcksyntheticxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      in
      (* Construct minimal mock accounts for source/receiver/feePayer; the
         persona may not have entries for arbitrary public keys, so we
         synthesize them. *)
      let placeholder_account pk : Mock_types.mock_account =
        match Mock_types.mock_account_of_persona persona ~public_key:pk with
        | Some a ->
            a
        | None ->
            { mock_public_key = pk
            ; mock_token_id = "1"
            ; mock_nonce = Some "0"
            ; mock_inferred_nonce = Some "0"
            ; mock_delegate = None
            ; mock_receipt_chain_hash = None
            ; mock_voting_for = None
            ; mock_staking_active = false
            ; mock_private_key_path = "/dev/null"
            ; mock_locked = None
            ; mock_index = None
            ; mock_zkapp_uri = None
            ; mock_proved_state = None
            ; mock_token_symbol = None
            }
      in
      let from_acct = placeholder_account input.sp_from in
      let to_acct = placeholder_account input.sp_to in
      let user_command : Mock_types.mock_user_command =
        { uc_id = synthetic_hash
        ; uc_hash = synthetic_hash
        ; uc_kind = "PAYMENT"
        ; uc_nonce = (
            match input.sp_nonce with
            | Some n -> ( try int_of_string n with _ -> 0 )
            | None -> 0 )
        ; uc_from_pk = input.sp_from
        ; uc_to_pk = input.sp_to
        ; uc_amount = input.sp_amount
        ; uc_fee = input.sp_fee
        ; uc_memo = Option.value input.sp_memo ~default:""
        ; uc_token = "1"
        ; uc_fee_token = "1"
        ; uc_valid_until =
            Option.value input.sp_valid_until ~default:"4294967295"
        ; uc_is_delegation = false
        ; uc_failure_reason = None
        ; uc_source_account = from_acct
        ; uc_receiver_account = to_acct
        ; uc_fee_payer_account = from_acct
        }
      in
      Async.return (Ok user_command) )

let mutations = [ start_filtered_log; send_payment ]

(* ---------- Subscriptions ---------- *)

let subscriptions = []

(* ---------- Schema ---------- *)

let schema = schema queries ~mutations ~subscriptions
