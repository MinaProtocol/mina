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

let transaction_id : (Mock_context.t, string option) typ =
  scalar "TransactionId" ~doc:"Base64-encoded transaction"
    ~coerce:(fun s -> `String s)

let transaction_hash : (Mock_context.t, string option) typ =
  scalar "TransactionHash" ~doc:"Base58Check-encoded transaction hash"
    ~coerce:(fun s -> `String s)

let global_slot : (Mock_context.t, string option) typ =
  scalar "Globalslot" ~doc:"String representation of a global slot"
    ~coerce:(fun s -> `String s)

(* UserCommandKind and TransactionStatusFailure are SCALARS in the real
   schema (not enums), per graphql_schema.json. *)
let user_command_kind : (Mock_context.t, string option) typ =
  scalar "UserCommandKind" ~doc:"The kind of user command"
    ~coerce:(fun s -> `String s)

let transaction_status_failure : (Mock_context.t, string option) typ =
  scalar "TransactionStatusFailure" ~doc:"Reason for a transaction failure"
    ~coerce:(fun s -> `String s)

let balance_scalar : (Mock_context.t, string option) typ =
  scalar "Balance" ~doc:"String representation of an account balance"
    ~coerce:(fun s -> `String s)

let length_scalar : (Mock_context.t, string option) typ =
  scalar "Length" ~doc:"String representation of a length (UInt32)"
    ~coerce:(fun s -> `String s)

let state_hash_scalar : (Mock_context.t, string option) typ =
  scalar "StateHash" ~doc:"Base58Check-encoded state hash"
    ~coerce:(fun s -> `String s)

let field_elem : (Mock_context.t, string option) typ =
  scalar "FieldElem" ~doc:"String representation of a Field element"
    ~coerce:(fun s -> `String s)

let global_slot_span : (Mock_context.t, string option) typ =
  scalar "GlobalSlotSpan"
    ~doc:"String representation of a span between two global slots"
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

let uint32_arg =
  Arg.scalar "UInt32" ~doc:"String-encoded UInt32"
    ~coerce:(function
      | `String s ->
          Ok s
      | `Int i ->
          Ok (string_of_int i)
      | _ ->
          Error "Expected uint32 as string or int" )

let uint64_arg =
  Arg.scalar "UInt64" ~doc:"String-encoded UInt64"
    ~coerce:(function
      | `String s ->
          Ok s
      | `Int i ->
          Ok (string_of_int i)
      | _ ->
          Error "Expected uint64 as string or int" )

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

(** TransactionStatus — INCLUDED/PENDING/UNKNOWN. The persona's
    [transactions] map carries one of these strings per tx hash. *)
type transaction_status = INCLUDED | PENDING | UNKNOWN

let parse_transaction_status : string -> transaction_status = function
  | "INCLUDED" ->
      INCLUDED
  | "PENDING" ->
      PENDING
  | "UNKNOWN" ->
      UNKNOWN
  | other ->
      failwith
        ("persona.json: unknown transaction status " ^ other
       ^ " (expected INCLUDED/PENDING/UNKNOWN)" )

let transaction_status_typ : (Mock_context.t, transaction_status option) typ =
  enum "TransactionStatus" ~doc:"Status of a transaction"
    ~values:
      [ enum_value "INCLUDED" ~value:INCLUDED
          ~doc:"A transaction that is on the longest chain"
      ; enum_value "PENDING" ~value:PENDING
          ~doc:
            "A transaction either in the transition frontier or in transaction \
             pool but is not on the longest chain"
      ; enum_value "UNKNOWN" ~value:UNKNOWN
          ~doc:"The transaction has either reached finality or is unknown"
      ]

(* ---------- Peer / AddrsAndPorts ---------- *)

(* Defined here (before DaemonStatus) so daemon_status can reference them. *)

type mock_peer =
  { peer_host : string
  ; peer_libp2p_port : int
  ; peer_id : string
  }

let peer : (Mock_context.t, mock_peer option) typ =
  obj "Peer" ~fields:(fun _info ->
      [ field "host" ~typ:(non_null string) ~args:Arg.[]
          ~resolve:(fun _ (p : mock_peer) -> p.peer_host)
      ; field "libp2pPort" ~typ:(non_null int) ~args:Arg.[]
          ~resolve:(fun _ (p : mock_peer) -> p.peer_libp2p_port)
      ; field "peerId" ~typ:(non_null string) ~args:Arg.[]
          ~resolve:(fun _ (p : mock_peer) -> p.peer_id)
      ] )

type mock_addrs_and_ports =
  { ap_external_ip : string
  ; ap_bind_ip : string
  ; ap_peer : mock_peer option
  ; ap_libp2p_port : int
  ; ap_client_port : int
  }

let addrs_and_ports : (Mock_context.t, mock_addrs_and_ports option) typ =
  obj "AddrsAndPorts" ~fields:(fun _info ->
      [ field "externalIp" ~typ:(non_null string) ~args:Arg.[]
          ~resolve:(fun _ (a : mock_addrs_and_ports) -> a.ap_external_ip)
      ; field "bindIp" ~typ:(non_null string) ~args:Arg.[]
          ~resolve:(fun _ (a : mock_addrs_and_ports) -> a.ap_bind_ip)
      ; field "peer" ~typ:peer ~args:Arg.[]
          ~resolve:(fun _ (a : mock_addrs_and_ports) -> a.ap_peer)
      ; field "libp2pPort" ~typ:(non_null int) ~args:Arg.[]
          ~resolve:(fun _ (a : mock_addrs_and_ports) -> a.ap_libp2p_port)
      ; field "clientPort" ~typ:(non_null int) ~args:Arg.[]
          ~resolve:(fun _ (a : mock_addrs_and_ports) -> a.ap_client_port)
      ] )

(* ---------- DaemonStatus ---------- *)

(* Mirrors a subset of Types.DaemonStatus.t. *)
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
      ; field "peers" ~typ:(non_null (list (non_null peer)))
          ~args:Arg.[]
          ~resolve:(fun _info (_d : Persona.daemon) ->
            (* Need access to the full persona to derive peers. The resolver
               for DaemonStatus already returns the daemon record as src;
               we don't have access to the wider persona here. Workaround:
               return a fixed-size list matching d.peers count, with
               synthetic per-peer data. *)
            List.init _d.peers (fun i ->
                { peer_host = Printf.sprintf "192.0.2.%d" (i + 1)
                ; peer_libp2p_port = 8302
                ; peer_id =
                    Printf.sprintf
                      "12D3KooWMockPeerId%dxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                      i
                } ) )
      ; field "addrsAndPorts" ~typ:(non_null addrs_and_ports)
          ~args:Arg.[]
          ~resolve:(fun _info (_d : Persona.daemon) ->
            { ap_external_ip = "203.0.113.42"
            ; ap_bind_ip = "0.0.0.0"
            ; ap_peer =
                Some
                  { peer_host = "127.0.0.1"
                  ; peer_libp2p_port = 8302
                  ; peer_id =
                      "12D3KooWMockSelfPeerIdxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
                  }
            ; ap_libp2p_port = 8302
            ; ap_client_port = 8301
            } )
      ] )

(* ---------- AccountTiming ---------- *)

(* The real schema's AccountTiming has all-nullable scalar fields; an
   "untimed" account has all None. v0.1 returns all-None for every
   account because the persona doesn't track vesting. *)
type mock_timing =
  { tim_initial_minimum_balance : string option
  ; tim_cliff_time : string option
  ; tim_cliff_amount : string option
  ; tim_vesting_period : string option
  ; tim_vesting_increment : string option
  }

let untimed : mock_timing =
  { tim_initial_minimum_balance = None
  ; tim_cliff_time = None
  ; tim_cliff_amount = None
  ; tim_vesting_period = None
  ; tim_vesting_increment = None
  }

let account_timing : (Mock_context.t, mock_timing option) typ =
  obj "AccountTiming" ~fields:(fun _info ->
      [ field "initialMinimumBalance" ~typ:balance_scalar ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_initial_minimum_balance)
      ; field "cliffTime" ~typ:global_slot ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_cliff_time)
      ; field "cliffAmount" ~typ:amount ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_cliff_amount)
      ; field "vestingPeriod" ~typ:global_slot_span ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_vesting_period)
      ; field "vestingIncrement" ~typ:amount ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_vesting_increment)
      ] )

(* ---------- AnnotatedBalance ---------- *)

(* Used as the inner type for Account.balance. All fields are scalar
   strings backed by the Balance/Length/StateHash scalar types. *)
type mock_balance =
  { bal_total : string
  ; bal_unknown : string
  ; bal_liquid : string option
  ; bal_locked : string option
  ; bal_block_height : string
  ; bal_state_hash : string option
  }

let annotated_balance : (Mock_context.t, mock_balance option) typ =
  obj "AnnotatedBalance" ~fields:(fun _info ->
      [ field "total" ~typ:(non_null balance_scalar) ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_total)
      ; field "unknown" ~typ:(non_null balance_scalar) ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_unknown)
      ; field "liquid" ~typ:balance_scalar ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_liquid)
      ; field "locked" ~typ:balance_scalar ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_locked)
      ; field "blockHeight" ~typ:(non_null length_scalar) ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_block_height)
      ; field "stateHash" ~typ:state_hash_scalar ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_state_hash)
      ] )

(* ---------- Account ---------- *)

(* A "mock account" — the source row for the Account object type. Mirrors a
   handful of the real fields. Future passes will add timing,
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
  ; mock_balance : mock_balance
  ; mock_leaf_hash : string option
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
      ; field "balance" ~typ:(non_null annotated_balance)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_balance)
      ; field "timing" ~typ:(non_null account_timing)
          ~args:Arg.[]
          ~resolve:(fun _ (_a : mock_account) -> untimed)
      ; field "leafHash" ~typ:field_elem
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_leaf_hash)
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
          let balance_str =
            Option.value (get_string_opt "balance") ~default:"0.000000000"
          in
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
            ; mock_balance =
                { bal_total = balance_str
                ; bal_unknown = "0"
                ; bal_liquid = Some balance_str
                ; bal_locked = Some "0"
                ; bal_block_height =
                    string_of_int persona.daemon.blockchain_length
                ; bal_state_hash = persona.daemon.state_hash
                }
            ; mock_leaf_hash = None
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

(* ---------- UserCommand interface + UserCommandPayment ---------- *)

(* A mock user command. Holds everything the interface fields read.
   Source/receiver/feePayer/fromAccount/toAccount are pre-resolved
   to mock_account so resolvers can return them synchronously. *)
type mock_user_command =
  { uc_id : string
  ; uc_hash : string
  ; uc_kind : string  (* "PAYMENT" | "STAKE_DELEGATION" | "ZKAPP" *)
  ; uc_nonce : int
  ; uc_from_pk : string
  ; uc_to_pk : string
  ; uc_amount : string
  ; uc_fee : string
  ; uc_memo : string
  ; uc_token : string
  ; uc_fee_token : string
  ; uc_valid_until : string
  ; uc_is_delegation : bool
  ; uc_failure_reason : string option
  ; uc_source_account : mock_account
  ; uc_receiver_account : mock_account
  ; uc_fee_payer_account : mock_account
  }

(* Interface definition; abstract_field declares the shape, each
   concrete object (currently just UserCommandPayment) provides matching
   field implementations. Order and signatures mirror Mina_graphql.types
   user_command_interface exactly.

   Explicit annotation defeats OCaml's value restriction: [interface] returns
   a polymorphic [abstract_typ] but it gets monomorphized when [add_type]
   binds a concrete impl, so we must pin the abstract source type here. *)
let user_command_interface :
    ( Mock_context.t
    , (Mock_context.t, mock_user_command) abstract_value option )
    typ =
  interface "UserCommand" ~doc:"Common interface for user commands"
    ~fields:(fun _ ->
      [ abstract_field "id" ~typ:(non_null transaction_id) ~args:[]
      ; abstract_field "hash" ~typ:(non_null transaction_hash) ~args:[]
      ; abstract_field "kind" ~typ:(non_null user_command_kind) ~args:[]
      ; abstract_field "nonce" ~typ:(non_null int) ~args:[]
      ; abstract_field "source" ~typ:(non_null account) ~args:[]
      ; abstract_field "receiver" ~typ:(non_null account) ~args:[]
      ; abstract_field "feePayer" ~typ:(non_null account) ~args:[]
      ; abstract_field "validUntil" ~typ:(non_null global_slot) ~args:[]
      ; abstract_field "token" ~typ:(non_null token_id) ~args:[]
      ; abstract_field "amount" ~typ:(non_null amount) ~args:[]
      ; abstract_field "feeToken" ~typ:(non_null token_id) ~args:[]
      ; abstract_field "fee" ~typ:(non_null fee) ~args:[]
      ; abstract_field "memo" ~typ:(non_null string) ~args:[]
      ; abstract_field "isDelegation" ~typ:(non_null bool) ~args:[]
      ; abstract_field "from" ~typ:(non_null public_key) ~args:[]
      ; abstract_field "fromAccount" ~typ:(non_null account) ~args:[]
      ; abstract_field "to" ~typ:(non_null public_key) ~args:[]
      ; abstract_field "toAccount" ~typ:(non_null account) ~args:[]
      ; abstract_field "failureReason" ~typ:transaction_status_failure
          ~args:[]
      ] )

(* Shared field definitions, reused across all concrete UserCommand impls. *)
let user_command_shared_fields : (Mock_context.t, mock_user_command) field list =
  [ field "id" ~typ:(non_null transaction_id) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_id)
  ; field "hash" ~typ:(non_null transaction_hash) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_hash)
  ; field "kind" ~typ:(non_null user_command_kind) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_kind)
  ; field "nonce" ~typ:(non_null int) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_nonce)
  ; field "source" ~typ:(non_null account) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_source_account)
  ; field "receiver" ~typ:(non_null account) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_receiver_account)
  ; field "feePayer" ~typ:(non_null account) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee_payer_account)
  ; field "validUntil" ~typ:(non_null global_slot) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_valid_until)
  ; field "token" ~typ:(non_null token_id) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_token)
  ; field "amount" ~typ:(non_null amount) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_amount)
  ; field "feeToken" ~typ:(non_null token_id) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee_token)
  ; field "fee" ~typ:(non_null fee) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee)
  ; field "memo" ~typ:(non_null string) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_memo)
  ; field "isDelegation" ~typ:(non_null bool) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_is_delegation)
  ; field "from" ~typ:(non_null public_key) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_from_pk)
  ; field "fromAccount" ~typ:(non_null account) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_source_account)
  ; field "to" ~typ:(non_null public_key) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_to_pk)
  ; field "toAccount" ~typ:(non_null account) ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_receiver_account)
  ; field "failureReason" ~typ:transaction_status_failure ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_failure_reason)
  ]

let user_command_payment =
  obj "UserCommandPayment" ~fields:(fun _ -> user_command_shared_fields)

(* Register UserCommandPayment as a concrete implementor of UserCommand. *)
let mk_payment = add_type user_command_interface user_command_payment

(* ---------- SignatureInput ---------- *)

type mock_signature =
  { sig_field : string option
  ; sig_scalar : string option
  ; sig_raw : string option
  }

let signature_input =
  Arg.obj "SignatureInput"
    ~doc:
      "A cryptographic signature -- you must provide either field+scalar \
       or rawSignature"
    ~coerce:(fun field scalar raw ->
      { sig_field = field; sig_scalar = scalar; sig_raw = raw } )
    ~fields:
      Arg.
        [ arg "field" ~typ:string ~doc:"Field component of signature"
        ; arg "scalar" ~typ:string ~doc:"Scalar component of signature"
        ; arg "rawSignature" ~typ:string ~doc:"Raw encoded signature"
        ]

(* ---------- SendPaymentInput ---------- *)

type send_payment_input =
  { sp_from : string
  ; sp_to : string
  ; sp_amount : string
  ; sp_fee : string
  ; sp_valid_until : string option
  ; sp_memo : string option
  ; sp_nonce : string option
  }

let send_payment_input =
  Arg.obj "SendPaymentInput"
    ~coerce:(fun nonce memo valid_until fee amount to_ from_ ->
      { sp_from = from_
      ; sp_to = to_
      ; sp_amount = amount
      ; sp_fee = fee
      ; sp_valid_until = valid_until
      ; sp_memo = memo
      ; sp_nonce = nonce
      } )
    ~fields:
      Arg.
        [ arg "nonce" ~typ:uint32_arg
            ~doc:"Should only be set when cancelling transactions, otherwise a nonce is determined automatically"
        ; arg "memo" ~typ:string ~doc:"Short arbitrary message provided by the sender"
        ; arg "validUntil" ~typ:uint32_arg
            ~doc:"The global slot since genesis after which this transaction cannot be applied"
        ; arg "fee" ~typ:(non_null uint64_arg)
            ~doc:"Fee amount in order to send payment"
        ; arg "amount" ~typ:(non_null uint64_arg) ~doc:"Amount of MINA to send to receiver"
        ; arg "to" ~typ:(non_null public_key_arg) ~doc:"Public key of recipient of payment"
        ; arg "from" ~typ:(non_null public_key_arg) ~doc:"Public key of sender of payment"
        ]

(* ---------- SendPaymentPayload ---------- *)

let send_payment_payload : (Mock_context.t, mock_user_command option) typ =
  obj "SendPaymentPayload" ~fields:(fun _ ->
      [ field "payment" ~typ:(non_null user_command_interface)
          ~args:Arg.[]
          ~doc:"Payment that has been enqueued for inclusion (mock)"
          ~resolve:(fun _ (u : mock_user_command) -> mk_payment u)
      ] )

(* ---------- SendDelegationInput / Payload ---------- *)

(* Same as send_payment_input minus [amount]. *)
type send_delegation_input =
  { sd_from : string
  ; sd_to : string
  ; sd_fee : string
  ; sd_valid_until : string option
  ; sd_memo : string option
  ; sd_nonce : string option
  }

let send_delegation_input =
  Arg.obj "SendDelegationInput"
    ~coerce:(fun nonce memo valid_until fee to_ from_ ->
      { sd_from = from_
      ; sd_to = to_
      ; sd_fee = fee
      ; sd_valid_until = valid_until
      ; sd_memo = memo
      ; sd_nonce = nonce
      } )
    ~fields:
      Arg.
        [ arg "nonce" ~typ:uint32_arg
        ; arg "memo" ~typ:string
        ; arg "validUntil" ~typ:uint32_arg
        ; arg "fee" ~typ:(non_null uint64_arg)
        ; arg "to" ~typ:(non_null public_key_arg)
        ; arg "from" ~typ:(non_null public_key_arg)
        ]

(* Mock returns delegations as UserCommandPayment objects with
   kind="STAKE_DELEGATION", isDelegation=true. The real schema has a
   separate UserCommandDelegation concrete impl that we don't bother
   defining; introspection-wise our UserCommand interface still has the
   same field shape, just one fewer possibleType. *)
let send_delegation_payload : (Mock_context.t, mock_user_command option) typ =
  obj "SendDelegationPayload" ~fields:(fun _ ->
      [ field "delegation" ~typ:(non_null user_command_interface)
          ~args:Arg.[]
          ~doc:"Delegation that has been enqueued for inclusion (mock)"
          ~resolve:(fun _ (u : mock_user_command) -> mk_payment u)
      ] )

(* TODO as resolvers come online:
   - peers / addrs_and_ports / metrics → object types
   - histograms / consensus* → object types
   - timing/balance on Account → AccountTiming, AnnotatedBalance types
   - UserCommandDelegation / UserCommandZkapp (variant impls of UserCommand)
   - Block type (large; needed for bestChain/block/genesisBlock) *)
