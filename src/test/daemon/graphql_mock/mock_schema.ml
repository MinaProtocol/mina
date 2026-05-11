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

(* wallet, accounts, tokenAccounts — three Account-shaped queries. *)

let wallet =
  io_field "wallet"
    ~doc:"Find any wallet via a public key (mock; alias for account)"
    ~typ:Mock_types.account
    ~args:Arg.[ arg "publicKey" ~typ:(non_null Mock_types.public_key_arg) ]
    ~resolve:(fun { ctx = persona; _ } () public_key ->
      Async.return
        (Ok (Mock_types.mock_account_of_persona persona ~public_key)) )

(* Real schema returns multiple Accounts when the same public key holds
   accounts on multiple tokens. The mock keeps a 1:1 mapping (one
   default-token account per pk), so we return a singleton list when the
   pk is known, empty list otherwise. *)
let accounts =
  io_field "accounts"
    ~doc:"Find all accounts for a given public key (mock; returns at most 1)"
    ~typ:(non_null (list (non_null Mock_types.account)))
    ~args:Arg.[ arg "publicKey" ~typ:(non_null Mock_types.public_key_arg) ]
    ~resolve:(fun { ctx = persona; _ } () public_key ->
      Async.return
        (Ok
           ( match
               Mock_types.mock_account_of_persona persona ~public_key
             with
           | Some a ->
               [ a ]
           | None ->
               [] ) ) )

(* Mock cheat: returns every account in the persona regardless of tokenId,
   because the persona doesn't track per-token ownership. *)
let token_accounts =
  io_field "tokenAccounts"
    ~doc:"Find all accounts for a given token (mock: returns every persona account)"
    ~typ:(non_null (list (non_null Mock_types.account)))
    ~args:Arg.[ arg "tokenId" ~typ:(non_null Mock_types.token_id_arg) ]
    ~resolve:(fun { ctx = persona; _ } () _token_id ->
      let pks =
        match persona.Persona.accounts with
        | `Assoc pairs ->
            List.map fst pairs
        | _ ->
            []
      in
      let accounts =
        List.filter_map
          (fun pk ->
            Mock_types.mock_account_of_persona persona ~public_key:pk )
          pks
      in
      Async.return (Ok accounts) )

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

(* currentSnarkWorker — mock returns a placeholder snark worker
   associated with Alice (the block producer). Real daemon returns null
   when no snark worker is configured; the mock always returns one. *)
let current_snark_worker =
  io_field "currentSnarkWorker"
    ~doc:"Get information about the current snark worker (mock)"
    ~typ:Mock_types.snark_worker
    ~args:Arg.[]
    ~resolve:(fun { ctx = persona; _ } () ->
      let bp = persona.Persona.daemon.block_producer_account in
      let account_opt =
        Mock_types.mock_account_of_persona persona ~public_key:bp
      in
      Async.return
        (Ok
           ( match account_opt with
           | Some a ->
               Some
                 { Mock_types.sw_key = bp
                 ; sw_account = a
                 ; sw_fee = "0.025"
                 }
           | None ->
               None ) ) )

(* trustStatus + trustStatusAll — peer trust scoring. Mock returns canned
   values. *)
let canned_trust_entry ip : Mock_types.mock_trust_status =
  { ts_ip_addr = ip
  ; ts_peer_id =
      "12D3KooWMockTrustPeerIdxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  ; ts_trust = 1.0
  ; ts_banned_status = None
  }

let trust_status =
  io_field "trustStatus"
    ~doc:"Trust status for an IPv4 or IPv6 address (mock)"
    ~typ:(list (non_null Mock_types.trust_status_payload))
    ~args:Arg.[ arg "ipAddress" ~typ:(non_null string) ]
    ~resolve:(fun _ () ip_addr -> Async.return (Ok (Some [ canned_trust_entry ip_addr ])))

let trust_status_all =
  io_field "trustStatusAll"
    ~doc:"IP address and trust status for all peers (mock)"
    ~typ:(non_null (list (non_null Mock_types.trust_status_payload)))
    ~args:Arg.[]
    ~resolve:(fun _ () ->
      Async.return
        (Ok [ canned_trust_entry "192.0.2.1"; canned_trust_entry "192.0.2.2" ]) )

(* bestChain — slice of the persona's blocks, ordered oldest-first.
   Real schema: bestChain(maxLength: Int): [Block!]. Returns null if no
   chain is known; the mock always returns the persona's blocks. *)
let best_chain =
  io_field "bestChain"
    ~doc:"Retrieve a list of blocks from transition frontier's root to the current best tip (mock)"
    ~typ:(list (non_null Mock_types.block_typ))
    ~args:
      Arg.[ arg "maxLength" ~typ:int ~doc:"The maximum number of blocks to return" ]
    ~resolve:(fun { ctx = persona; _ } () max_length ->
      let all = Mock_types.mock_blocks persona in
      let total = List.length all in
      let n =
        match max_length with
        | Some n when n > 0 && n < total ->
            n
        | _ ->
            total
      in
      let rec drop k xs =
        match (k, xs) with
        | 0, xs ->
            xs
        | _, [] ->
            []
        | k, _ :: rest ->
            drop (k - 1) rest
      in
      Async.return (Ok (Some (drop (total - n) all))) )

(* block(height|stateHash) — look up a specific block. Returns the first
   match for either filter, or the latest block if neither is given. *)
let block_query =
  io_field "block"
    ~doc:"Retrieve a block with the given state hash or height (mock)"
    ~typ:(non_null Mock_types.block_typ)
    ~args:
      Arg.
        [ arg "height" ~typ:int ~doc:"Block height"
        ; arg "stateHash" ~typ:string ~doc:"State hash of the desired block"
        ]
    ~resolve:(fun { ctx = persona; _ } () height state_hash ->
      let blocks =
        match persona.Persona.blocks with `List xs -> xs | _ -> []
      in
      let open Yojson.Safe.Util in
      let pick =
        List.find_opt
          (fun b ->
            let h =
              match b |> member "height" with
              | `Int n ->
                  Some n
              | _ ->
                  None
            in
            let sh =
              match b |> member "stateHash" with
              | `String s ->
                  Some s
              | _ ->
                  None
            in
            match (height, state_hash) with
            | Some n, _ when h = Some n ->
                true
            | _, Some s when sh = Some s ->
                true
            | _ ->
                false )
          blocks
      in
      let chosen =
        match pick with
        | Some b ->
            b
        | None ->
            (* No filter or no match → fall back to first persona block *)
            ( match blocks with
            | b :: _ ->
                b
            | [] ->
                `Assoc [] )
      in
      Async.return (Ok (Mock_types.mock_block_of_json persona chosen)) )

let genesis_block_query =
  io_field "genesisBlock"
    ~doc:"Get the genesis block (mock: returns the oldest persona block)"
    ~typ:(non_null Mock_types.block_typ)
    ~args:Arg.[]
    ~resolve:(fun { ctx = persona; _ } () ->
      let blocks = Mock_types.mock_blocks persona in
      match blocks with
      | b :: _ ->
          Async.return (Ok b)
      | [] ->
          Async.return
            (Ok
               (Mock_types.mock_block_of_json persona (`Assoc []))) )

(* String / JSON returning admin queries — pure echo. *)

let runtime_config =
  io_field "runtimeConfig"
    ~doc:"The runtime configuration the daemon is running with (mock)"
    ~typ:(non_null Mock_types.json_scalar)
    ~args:Arg.[]
    ~resolve:(fun _ () ->
      Async.return
        (Ok
           (`Assoc
             [ ("genesis", `Assoc [ ("k", `Int 290) ])
             ; ("daemon", `Assoc [])
             ; ("mock", `Bool true)
             ] )) )

let blockchain_verification_key =
  io_field "blockchainVerificationKey"
    ~doc:"The blockchain verification key (mock)"
    ~typ:(non_null Mock_types.json_scalar)
    ~args:Arg.[]
    ~resolve:(fun _ () ->
      Async.return
        (Ok
           (`Assoc
             [ ("mock_verification_key", `String "AACGfBASrjLO9V8mock")
             ; ("hash", `String "0x0123abcd")
             ] )) )

let thread_graph =
  io_field "threadGraph"
    ~doc:"A serialized representation of the daemon's thread structure (mock)"
    ~typ:(non_null string)
    ~args:Arg.[]
    ~resolve:(fun _ () ->
      Async.return
        (Ok "digraph threads { mock_thread_root -> mock_thread_worker; }") )

let network_id_query =
  io_field "networkID"
    ~doc:"The identifier for the current network (mock: \"mina:mock\")"
    ~typ:(non_null string)
    ~args:Arg.[]
    ~resolve:(fun _ () -> Async.return (Ok "mina:mock"))

let signature_kind_query =
  io_field "signatureKind"
    ~doc:"The signature kind used by this network (mock: \"testnet\")"
    ~typ:(non_null string)
    ~args:Arg.[]
    ~resolve:(fun _ () -> Async.return (Ok "testnet"))

let protocol_state_query =
  io_field "protocolState"
    ~doc:"The protocol state of a block as a Base64 or JSON encoded string (mock)"
    ~typ:(non_null string)
    ~args:
      Arg.
        [ arg "encoding" ~doc:"Output format — JSON or BASE64"
            ~typ:
              (enum "Encoding"
                 ~values:
                   [ enum_value "JSON" ~value:Mock_types.JSON_ENC
                   ; enum_value "BASE64" ~value:Mock_types.BASE64_ENC
                   ] )
        ; arg "height" ~typ:int
        ; arg "stateHash" ~typ:string
        ]
    ~resolve:(fun _ () _enc _h _sh ->
      Async.return
        (Ok "{\"mock\":true,\"protocol_state\":\"encoded\"}") )

(* snarkPool — list of completed snark work jobs. Mock returns one
   canned completed work, attributed to the persona's block producer. *)
let snark_pool =
  io_field "snarkPool"
    ~doc:"List of completed snark works in the pool (mock: returns one entry)"
    ~typ:(non_null (list (non_null Mock_types.completed_work)))
    ~args:Arg.[]
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return
        (Ok
           [ Mock_types.
               { cw_prover = persona.Persona.daemon.block_producer_account
               ; cw_fee = "0.025"
               ; cw_work_ids = [ 42 ]
               }
           ] ) )

(* Look up status of a transaction hash. The mock's persona.transactions
   map carries known hashes; unknown hashes return UNKNOWN. *)
let transaction_status =
  io_field "transactionStatus"
    ~doc:"Get the status of a transaction (mock)"
    ~typ:(non_null Mock_types.transaction_status_typ)
    ~args:
      Arg.
        [ arg "payment" ~typ:guid ~doc:"Id of a Payment"
        ; arg "zkappTransaction" ~typ:guid ~doc:"Id of a zkApp transaction"
        ]
    ~resolve:(fun { ctx = persona; _ } () payment_id zkapp_id ->
      let key = match payment_id with Some k -> Some k | None -> zkapp_id in
      let result =
        match (key, persona.Persona.transactions) with
        | Some key, `Assoc pairs -> (
            match List.assoc_opt key pairs with
            | Some json -> (
                match Yojson.Safe.Util.member "status" json with
                | `String s ->
                    Mock_types.parse_transaction_status s
                | _ ->
                    Mock_types.UNKNOWN )
            | None ->
                Mock_types.UNKNOWN )
        | _ ->
            Mock_types.UNKNOWN
      in
      Async.return (Ok result) )

(* pooledUserCommands returns the persona's mempool. v0.1 just returns ALL
   mempool entries regardless of the filter args — refining by ids/hashes/
   publicKey is incremental future work. *)
let pooled_user_commands =
  io_field "pooledUserCommands"
    ~doc:"Get all the scheduled user commands for a specified sender that the current daemon sees in their mempool (mock: returns all persona mempool entries, ignores filters)"
    ~typ:(non_null (list (non_null Mock_types.user_command_interface)))
    ~args:
      Arg.
        [ arg "ids" ~typ:(list (non_null guid))
            ~doc:"Ids of User commands"
        ; arg "hashes" ~typ:(list (non_null string))
            ~doc:"Hashes of User commands"
        ; arg "publicKey" ~typ:Mock_types.public_key_arg
            ~doc:"Public key of sender"
        ]
    ~resolve:(fun { ctx = persona; _ } () _ids _hashes _pk ->
      let entries =
        match persona.Persona.mempool with
        | `List xs ->
            xs
        | _ ->
            []
      in
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
            ; mock_balance =
                { bal_total = "0.000000000"
                ; bal_unknown = "0"
                ; bal_liquid = Some "0.000000000"
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.Persona.daemon.blockchain_length
                ; bal_state_hash = persona.Persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
            ; mock_permissions = Mock_types.default_permissions
            ; mock_verification_key = None
            }
      in
      let to_user_command (json : Yojson.Safe.t) : Mock_types.mock_user_command =
        let open Yojson.Safe.Util in
        let s f = json |> member f |> to_string in
        let s_opt f = json |> member f |> to_string_option in
        let from_pk = try s "from" with _ -> "" in
        let to_pk = try s "to" with _ -> "" in
        { uc_id = (try s "hash" with _ -> "")
        ; uc_hash = (try s "hash" with _ -> "")
        ; uc_kind = (try s "kind" with _ -> "PAYMENT")
        ; uc_nonce =
            ( match s_opt "nonce" with
            | Some n -> ( try int_of_string n with _ -> 0 )
            | None -> 0 )
        ; uc_from_pk = from_pk
        ; uc_to_pk = to_pk
        ; uc_amount = (try s "amount" with _ -> "0")
        ; uc_fee = (try s "fee" with _ -> "0")
        ; uc_memo = Option.value (s_opt "memo") ~default:""
        ; uc_token = "1"
        ; uc_fee_token = "1"
        ; uc_valid_until = "4294967295"
        ; uc_is_delegation =
            (try s "kind" = "STAKE_DELEGATION" with _ -> false)
        ; uc_failure_reason = s_opt "failureReason"
        ; uc_source_account = placeholder_account from_pk
        ; uc_receiver_account = placeholder_account to_pk
        ; uc_fee_payer_account = placeholder_account from_pk
        }
      in
      let commands = List.map to_user_command entries in
      Async.return
        (Ok
           (List.map
              (fun uc -> Mock_types.mk_payment uc)
              commands ) ) )

(* Type annotations on these lists are intentionally absent; let the compiler
   unify each field's context with [Mock_context.t] from the resolvers. *)
let queries =
  [ sync_status
  ; daemon_status
  ; version
  ; time_offset
  ; account
  ; wallet
  ; accounts
  ; token_owner
  ; token_accounts
  ; genesis_constants
  ; transaction_status
  ; pooled_user_commands
  ; current_snark_worker
  ; trust_status
  ; trust_status_all
  ; best_chain
  ; block_query
  ; genesis_block_query
  ; runtime_config
  ; blockchain_verification_key
  ; thread_graph
  ; network_id_query
  ; signature_kind_query
  ; protocol_state_query
  ; snark_pool
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
            ; mock_balance =
                { bal_total = "0.000000000"
                ; bal_unknown = "0"
                ; bal_liquid = Some "0.000000000"
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.Persona.daemon.blockchain_length
                ; bal_state_hash = persona.Persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
            ; mock_permissions = Mock_types.default_permissions
            ; mock_verification_key = None
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

(* sendDelegation — same shape as sendPayment, no amount, returns
   SendDelegationPayload { delegation: UserCommand! } *)
let send_delegation =
  io_field "sendDelegation"
    ~doc:"Change your delegate by sending a transaction (mock: returns canned synthetic tx)"
    ~typ:(non_null Mock_types.send_delegation_payload)
    ~args:
      Arg.
        [ arg "signature" ~typ:Mock_types.signature_input
        ; arg "input" ~typ:(non_null Mock_types.send_delegation_input)
        ]
    ~resolve:(fun { ctx = persona; _ } () _signature input ->
      let synthetic_hash =
        match persona.Persona.synthetic_tx_hashes with
        | `Assoc pairs -> (
            match List.assoc_opt "sendDelegation" pairs with
            | Some (`String s) ->
                s
            | _ ->
                "5JmoOckdelegationxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" )
        | _ ->
            "5JmoOckdelegationxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
      in
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
            ; mock_balance =
                { bal_total = "0.000000000"
                ; bal_unknown = "0"
                ; bal_liquid = Some "0.000000000"
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.Persona.daemon.blockchain_length
                ; bal_state_hash = persona.Persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
            ; mock_permissions = Mock_types.default_permissions
            ; mock_verification_key = None
            }
      in
      let from_acct = placeholder_account input.sd_from in
      let to_acct = placeholder_account input.sd_to in
      let user_command : Mock_types.mock_user_command =
        { uc_id = synthetic_hash
        ; uc_hash = synthetic_hash
        ; uc_kind = "STAKE_DELEGATION"
        ; uc_nonce =
            ( match input.sd_nonce with
            | Some n -> ( try int_of_string n with _ -> 0 )
            | None -> 0 )
        ; uc_from_pk = input.sd_from
        ; uc_to_pk = input.sd_to
        ; uc_amount = "0"
        ; uc_fee = input.sd_fee
        ; uc_memo = Option.value input.sd_memo ~default:""
        ; uc_token = "1"
        ; uc_fee_token = "1"
        ; uc_valid_until = Option.value input.sd_valid_until ~default:"4294967295"
        ; uc_is_delegation = true
        ; uc_failure_reason = None
        ; uc_source_account = from_acct
        ; uc_receiver_account = to_acct
        ; uc_fee_payer_account = from_acct
        }
      in
      Async.return (Ok user_command) )

(* Admin mutations: setSnarkWorker, setSnarkWorkFee, setCoinbaseReceiver.
   These don't mutate any real state in the mock — they just echo back
   what was set as if it took effect. *)

let set_snark_worker =
  io_field "setSnarkWorker"
    ~doc:"Set key you wish to snark work with or disable snark working (mock: echo)"
    ~typ:(non_null Mock_types.set_snark_worker_payload)
    ~args:Arg.[ arg "input" ~typ:(non_null Mock_types.set_snark_worker_input) ]
    ~resolve:(fun _ () input ->
      Async.return (Ok input.Mock_types.ssw_public_key) )

let set_snark_work_fee =
  io_field "setSnarkWorkFee"
    ~doc:"Set fee for snark workers (mock: echo)"
    ~typ:(non_null Mock_types.set_snark_work_fee_payload)
    ~args:Arg.[ arg "input" ~typ:(non_null Mock_types.set_snark_work_fee_input) ]
    ~resolve:(fun _ () input ->
      Async.return (Ok input.Mock_types.ssw_fee_fee) )

let set_coinbase_receiver =
  io_field "setCoinbaseReceiver"
    ~doc:"Set the coinbase receiver public key (mock: echo)"
    ~typ:(non_null Mock_types.set_coinbase_receiver_payload)
    ~args:Arg.[ arg "input" ~typ:(non_null Mock_types.set_coinbase_receiver_input) ]
    ~resolve:(fun { ctx = persona; _ } () input ->
      let prev = Some persona.Persona.daemon.block_producer_account in
      Async.return
        (Ok
           Mock_types.
             { mcb_last = prev
             ; mcb_current = input.scr_public_key
             } ) )

(* Lock/Unlock mutations — mock just looks up the account and returns it. *)

let lock_account_mut =
  io_field "lockAccount"
    ~doc:"Lock a tracked account (mock: returns the account unchanged)"
    ~typ:(non_null Mock_types.lock_payload)
    ~args:Arg.[ arg "input" ~typ:(non_null Mock_types.lock_input_arg) ]
    ~resolve:(fun { ctx = persona; _ } () input ->
      let pk = input.Mock_types.lock_public_key in
      let acct =
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
            ; mock_balance =
                { bal_total = "0.000000000"
                ; bal_unknown = "0"
                ; bal_liquid = Some "0.000000000"
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.Persona.daemon.blockchain_length
                ; bal_state_hash = persona.Persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
            ; mock_permissions = Mock_types.default_permissions
            ; mock_verification_key = None
            }
      in
      Async.return
        (Ok Mock_types.{ lp_public_key = pk; lp_account = acct }) )

let unlock_account_mut =
  io_field "unlockAccount"
    ~doc:"Allow transactions to be sent from the unlocked account (mock: returns the account)"
    ~typ:(non_null Mock_types.unlock_payload)
    ~args:Arg.[ arg "input" ~typ:(non_null Mock_types.unlock_input_arg) ]
    ~resolve:(fun { ctx = persona; _ } () input ->
      let pk = input.Mock_types.unlock_public_key in
      let acct =
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
            ; mock_balance =
                { bal_total = "0.000000000"
                ; bal_unknown = "0"
                ; bal_liquid = Some "0.000000000"
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.Persona.daemon.blockchain_length
                ; bal_state_hash = persona.Persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
            ; mock_permissions = Mock_types.default_permissions
            ; mock_verification_key = None
            }
      in
      Async.return
        (Ok Mock_types.{ lp_public_key = pk; lp_account = acct }) )

let mutations =
  [ start_filtered_log
  ; send_payment
  ; send_delegation
  ; set_snark_worker
  ; set_snark_work_fee
  ; set_coinbase_receiver
  ; lock_account_mut
  ; unlock_account_mut
  ]

(* ---------- Subscriptions ---------- *)

let subscriptions = []

(* ---------- Schema ---------- *)

let schema = schema queries ~mutations ~subscriptions
