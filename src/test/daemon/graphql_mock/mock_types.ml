(** GraphQL output types parallel to a subset of [Mina_graphql.Types].

    Only the types used by v0.1 resolvers are defined here. When adding a
    new resolver, mirror the shape of the corresponding type in
    [src/lib/graphql/mina_graphql/types.ml] — field names and nullability
    must match, otherwise [mock_schema.json] will diverge from
    [graphql_schema.json] and the drift CI will fail.

    Mock scalars are simple string passthroughs (no real public-key parsing,
    no balance arithmetic, etc.) — the persona supplies pre-formatted strings
    and the mock returns them verbatim. The scalar NAMES match the real
    daemon's so the subset check accepts them. *)

open Graphql_async
open Schema

(* ---------- Custom scalars (output) ---------- *)

(* Output scalars used in field return types. Name match is what makes the
   subset check happy; the values are just strings under the hood. *)

let public_key : (Mock_context.t, string option) typ =
  scalar "PublicKey" ~doc:"Base58Check-encoded public key string"
    ~coerce:(fun s -> `String s)

let token_id : (Mock_context.t, string option) typ =
  scalar "TokenId" ~doc:"String representation of a token's UInt64 identifier"
    ~coerce:(fun s -> `String s)

let account_nonce : (Mock_context.t, string option) typ =
  scalar "AccountNonce" ~doc:"Account nonce, represented as a string"
    ~coerce:(fun s -> `String s)

let chain_hash : (Mock_context.t, string option) typ =
  scalar "ChainHash" ~doc:"Base58Check-encoded chain hash"
    ~coerce:(fun s -> `String s)

let fee : (Mock_context.t, string option) typ =
  scalar "Fee" ~doc:"String representation of a transaction fee"
    ~coerce:(fun s -> `String s)

let amount : (Mock_context.t, string option) typ =
  scalar "Amount" ~doc:"String representation of a payment amount"
    ~coerce:(fun s -> `String s)

(* ---------- Custom scalars (input args) ---------- *)

(* Mirrors Types.Input.PublicKey.arg_typ. Real mina uses graphql_wrapper's
   extended [Arg.scalar] which adds [~to_json] for client variable encoding;
   the bare graphql-async version we depend on here doesn't have that, so
   [~to_json] is omitted. This affects only variable round-tripping shape,
   not the introspected schema, so subset detection is unaffected. *)
let public_key_arg =
  Arg.scalar "PublicKey" ~doc:"Public key in Base58Check format"
    ~coerce:(function
      | `String s ->
          Ok s
      | _ ->
          Error "Expected public key as a string in Base58Check format" )

let token_id_arg =
  Arg.scalar "TokenId" ~doc:"String representation of a token's UInt64 identifier"
    ~coerce:(function
      | `String s ->
          Ok s
      | _ ->
          Error "Expected token id as a string" )

(* ---------- Enums ---------- *)

(** Mirrors [Sync_status.t] from the daemon. The string representation
    matches the enum value names in graphql_schema.json. *)
type sync_status =
  | CONNECTING
  | LISTENING
  | OFFLINE
  | BOOTSTRAP
  | SYNCED
  | CATCHUP

let parse_sync_status : string -> sync_status = function
  | "CONNECTING" ->
      CONNECTING
  | "LISTENING" ->
      LISTENING
  | "OFFLINE" ->
      OFFLINE
  | "BOOTSTRAP" ->
      BOOTSTRAP
  | "SYNCED" ->
      SYNCED
  | "CATCHUP" ->
      CATCHUP
  | other ->
      failwith
        ("persona.json: unknown sync status " ^ other
       ^ " (expected one of CONNECTING/LISTENING/OFFLINE/BOOTSTRAP/SYNCED/CATCHUP)"
        )

let sync_status_typ : (Mock_context.t, sync_status option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
      [ enum_value "CONNECTING" ~value:CONNECTING
      ; enum_value "LISTENING" ~value:LISTENING
      ; enum_value "OFFLINE" ~value:OFFLINE
      ; enum_value "BOOTSTRAP" ~value:BOOTSTRAP
      ; enum_value "SYNCED" ~value:SYNCED
      ; enum_value "CATCHUP" ~value:CATCHUP
      ]

(* ---------- DaemonStatus ---------- *)

(* Mirrors a subset of Types.DaemonStatus.t, scoped to scalar/enum fields.
   Object-typed fields (peers, histograms, consensus*, addrs_and_ports,
   metrics, blockProductionKeys, …) remain unimplemented until those
   backing types come online. *)
let daemon_status : (Mock_context.t, Persona.daemon option) typ =
  obj "DaemonStatus" ~fields:(fun _info ->
      [ field "numAccounts" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.num_accounts)
      ; field "blockchainLength" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> Some d.blockchain_length)
      ; field "highestBlockLengthReceived" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.highest_block_length_received )
      ; field "highestUnvalidatedBlockLengthReceived" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.highest_unvalidated_block_length_received )
      ; field "uptimeSecs" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.uptime_secs)
      ; field "ledgerMerkleRoot" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.ledger_merkle_root)
      ; field "stateHash" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.state_hash)
      ; field "chainId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.chain_id)
      ; field "commitId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.commit_id)
      ; field "confDir" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.conf_dir)
      ; field "userCommandsSent" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.user_commands_sent)
      ; field "snarkWorker" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.snark_worker)
      ; field "snarkWorkFee" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.snark_work_fee)
      ; field "syncStatus" ~typ:(non_null sync_status_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            parse_sync_status d.sync_status )
      ; field "coinbaseReceiver" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.coinbase_receiver)
      ; field "globalSlotSinceGenesisBestTip" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.global_slot_since_genesis_best_tip )
      ; field "consensusMechanism" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.consensus_mechanism)
      ] )

(* ---------- Account ---------- *)

(* A "mock account" — the source row for the Account object type. Mirrors a
   handful of the real fields. Future passes will add timing, balance,
   permissions, zkappState, etc. as their backing types come online. *)
type mock_account =
  { mock_public_key : string
  ; mock_token_id : string
  ; mock_nonce : string option
  ; mock_inferred_nonce : string option
  ; mock_delegate : string option
  ; mock_receipt_chain_hash : string option
  ; mock_voting_for : string option
  ; mock_staking_active : bool
  ; mock_private_key_path : string
  ; mock_locked : bool option
  ; mock_index : int option
  ; mock_zkapp_uri : string option
  ; mock_proved_state : bool option
  ; mock_token_symbol : string option
  }

let account : (Mock_context.t, mock_account option) typ =
  obj "Account" ~fields:(fun _info ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_public_key)
      ; field "tokenId" ~typ:(non_null token_id)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_token_id)
      ; field "token" ~typ:(non_null token_id)
          ~doc:"Alias for tokenId"
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_token_id)
      ; field "nonce" ~typ:account_nonce
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_nonce)
      ; field "inferredNonce" ~typ:account_nonce
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_inferred_nonce)
      ; field "delegate" ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_delegate)
      ; field "receiptChainHash" ~typ:chain_hash
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_receipt_chain_hash)
      ; field "votingFor" ~typ:chain_hash
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_voting_for)
      ; field "stakingActive" ~typ:(non_null bool)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_staking_active)
      ; field "privateKeyPath" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_private_key_path)
      ; field "locked" ~typ:bool
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_locked)
      ; field "index" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_index)
      ; field "zkappUri" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_zkapp_uri)
      ; field "provedState" ~typ:bool
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_proved_state)
      ; field "tokenSymbol" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_token_symbol)
      ] )

(** Lookup an account in the persona's [accounts] JSON object by public key.
    Returns a [mock_account] populated from the persona, or None if the key
    isn't known to the canned world. *)
let mock_account_of_persona (persona : Persona.t) ~public_key : mock_account option =
  match persona.accounts with
  | `Assoc pairs -> (
      match List.assoc_opt public_key pairs with
      | None ->
          None
      | Some json ->
          let open Yojson.Safe.Util in
          let get_string_opt name = json |> member name |> to_string_option in
          let get_bool_opt name = json |> member name |> to_bool_option in
          Some
            { mock_public_key = public_key
            ; mock_token_id =
                Option.value (get_string_opt "tokenId") ~default:"1"
            ; mock_nonce = get_string_opt "nonce"
            ; mock_inferred_nonce = get_string_opt "nonce"
            ; mock_delegate = get_string_opt "delegate"
            ; mock_receipt_chain_hash = get_string_opt "receiptChainHash"
            ; mock_voting_for = get_string_opt "votingFor"
            ; mock_staking_active =
                Option.value (get_bool_opt "stakingActive") ~default:false
            ; mock_private_key_path =
                Option.value
                  (get_string_opt "privateKeyPath")
                  ~default:"/dev/null"
            ; mock_locked = get_bool_opt "locked"
            ; mock_index = json |> member "index" |> to_int_option
            ; mock_zkapp_uri = get_string_opt "zkappUri"
            ; mock_proved_state = get_bool_opt "provedState"
            ; mock_token_symbol = get_string_opt "tokenSymbol"
            } )
  | _ ->
      None

(* ---------- GenesisConstants ---------- *)

type mock_genesis_constants =
  { mock_account_creation_fee : string
  ; mock_coinbase : string
  ; mock_genesis_timestamp : string
  }

let genesis_constants : (Mock_context.t, mock_genesis_constants option) typ =
  obj "GenesisConstants"
    ~doc:"Constants used to configure the genesis ledger (mock)"
    ~fields:(fun _info ->
      [ field "accountCreationFee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~resolve:(fun _ (g : mock_genesis_constants) ->
            g.mock_account_creation_fee )
      ; field "coinbase" ~typ:(non_null amount)
          ~args:Arg.[]
          ~resolve:(fun _ (g : mock_genesis_constants) -> g.mock_coinbase)
      ; field "genesisTimestamp" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (g : mock_genesis_constants) ->
            g.mock_genesis_timestamp )
      ] )

(* Static canned constants. Could be promoted to a persona field if we ever
   want to vary them per persona. *)
let canned_genesis_constants =
  { mock_account_creation_fee = "1.0"
  ; mock_coinbase = "720.0"
  ; mock_genesis_timestamp = "2024-01-01T00:00:00Z"
  }

(* TODO as resolvers come online:
   - peers / addrs_and_ports / metrics → object types
   - histograms / consensus* → object types
   - timing/balance on Account → AccountTiming, AnnotatedBalance types
   - send_payment_payload → UserCommand interface + Payment/Delegation/Zkapp objects
     + TransactionId/TransactionHash/UserCommandKind/Globalslot/UInt32/UInt64
     + TransactionStatusFailure enum *)
