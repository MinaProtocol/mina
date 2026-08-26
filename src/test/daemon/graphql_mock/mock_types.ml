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
  scalar "ChainHash" ~doc:"Base58Check-encoded chain hash" ~coerce:(fun s ->
      `String s )

let fee : (Mock_context.t, string option) typ =
  scalar "Fee" ~doc:"String representation of a transaction fee"
    ~coerce:(fun s -> `String s)

let amount : (Mock_context.t, string option) typ =
  scalar "Amount" ~doc:"String representation of a payment amount"
    ~coerce:(fun s -> `String s)

let transaction_id : (Mock_context.t, string option) typ =
  scalar "TransactionId" ~doc:"Base64-encoded transaction" ~coerce:(fun s ->
      `String s )

let transaction_hash : (Mock_context.t, string option) typ =
  scalar "TransactionHash" ~doc:"Base58Check-encoded transaction hash"
    ~coerce:(fun s -> `String s)

let global_slot : (Mock_context.t, string option) typ =
  scalar "Globalslot" ~doc:"String representation of a global slot"
    ~coerce:(fun s -> `String s)

(* UserCommandKind and TransactionStatusFailure are SCALARS in the real
   schema (not enums), per graphql_schema.json. *)
let user_command_kind : (Mock_context.t, string option) typ =
  scalar "UserCommandKind" ~doc:"The kind of user command" ~coerce:(fun s ->
      `String s )

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
  scalar "StateHash" ~doc:"Base58Check-encoded state hash" ~coerce:(fun s ->
      `String s )

let field_elem : (Mock_context.t, string option) typ =
  scalar "FieldElem" ~doc:"String representation of a Field element"
    ~coerce:(fun s -> `String s)

let global_slot_span : (Mock_context.t, string option) typ =
  scalar "GlobalSlotSpan"
    ~doc:"String representation of a span between two global slots"
    ~coerce:(fun s -> `String s)

let time_scalar : (Mock_context.t, string option) typ =
  scalar "Time" ~doc:"ISO-8601 timestamp" ~coerce:(fun s -> `String s)

let verification_key : (Mock_context.t, string option) typ =
  scalar "VerificationKey" ~doc:"Base64-encoded verification key"
    ~coerce:(fun s -> `String s)

let verification_key_hash : (Mock_context.t, string option) typ =
  scalar "VerificationKeyHash" ~doc:"Hash of the verification key"
    ~coerce:(fun s -> `String s)

let inet_addr : (Mock_context.t, string option) typ =
  scalar "InetAddr" ~doc:"String representation of an Internet address"
    ~coerce:(fun s -> `String s)

let state_hash_as_decimal : (Mock_context.t, string option) typ =
  scalar "StateHashAsDecimal" ~doc:"State hash as a decimal string"
    ~coerce:(fun s -> `String s)

(* zkApp-related scalars. *)
let memo_scalar : (Mock_context.t, string option) typ =
  scalar "Memo" ~doc:"Base58Check-encoded memo (max 32 bytes)" ~coerce:(fun s ->
      `String s )

let index_scalar : (Mock_context.t, string option) typ =
  scalar "Index" ~doc:"String-encoded UInt32 index" ~coerce:(fun s -> `String s)

let zkapp_proof : (Mock_context.t, string option) typ =
  scalar "ZkappProof" ~doc:"Base64-encoded zkApp proof" ~coerce:(fun s ->
      `String s )

let signature_scalar : (Mock_context.t, string option) typ =
  scalar "Signature" ~doc:"Base58Check-encoded signature" ~coerce:(fun s ->
      `String s )

let field_scalar : (Mock_context.t, string option) typ =
  scalar "Field" ~doc:"String representation of a Field element"
    ~coerce:(fun s -> `String s)

let global_slot_since_genesis : (Mock_context.t, string option) typ =
  scalar "GlobalSlotSinceGenesis"
    ~doc:"String representation of a global slot (since genesis)"
    ~coerce:(fun s -> `String s)

(* JSON scalar — daemon's catch-all for unstructured config payloads.
   Mock carries values as raw [Yojson.Basic.t] so client receives proper
   JSON, not a stringified blob. *)
let json_scalar : (Mock_context.t, Yojson.Basic.t option) typ =
  scalar "JSON" ~doc:"Arbitrary JSON" ~coerce:(fun s -> s)

(* Argument-side variants of zkApp scalars. *)
let memo_arg =
  Arg.scalar "Memo" ~doc:"Base58Check-encoded memo" ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string memo" )

let signature_scalar_arg =
  Arg.scalar "Signature" ~doc:"Base58Check-encoded signature" ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string signature" )

let zkapp_proof_arg =
  Arg.scalar "ZkappProof" ~doc:"Base64-encoded zkApp proof" ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string proof" )

let field_arg =
  Arg.scalar "Field" ~doc:"String representation of a Field element"
    ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string field" )

let global_slot_since_genesis_arg =
  Arg.scalar "GlobalSlotSinceGenesis"
    ~doc:"String representation of a global slot (since genesis)"
    ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string global slot" )

let fee_arg =
  Arg.scalar "Fee" ~doc:"String representation of a transaction fee"
    ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected string fee" )

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
  Arg.scalar "TokenId"
    ~doc:"String representation of a token's UInt64 identifier"
    ~coerce:(function
    | `String s ->
        Ok s
    | _ ->
        Error "Expected token id as a string" )

let uint32_arg =
  Arg.scalar "UInt32" ~doc:"String-encoded UInt32" ~coerce:(function
    | `String s ->
        Ok s
    | `Int i ->
        Ok (string_of_int i)
    | _ ->
        Error "Expected uint32 as string or int" )

let uint64_arg =
  Arg.scalar "UInt64" ~doc:"String-encoded UInt64" ~coerce:(function
    | `String s ->
        Ok s
    | `Int i ->
        Ok (string_of_int i)
    | _ ->
        Error "Expected uint64 as string or int" )

(* ---------- Enums ---------- *)

(** Mirrors [Sync_status.t] from the daemon. The string representation
    matches the enum value names in graphql_schema.json. *)
(* SyncStatus enum + DaemonStatus type are produced by the shared functor
   in [Mina_graphql.Types.Make_daemon_status], instantiated in
   [Mock_schema] over [Mock_context.t]. See [Persona_to_status] for the
   adapter that supplies the real [Daemon_rpcs.Types.Status.t] record. *)

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
        ( "persona.json: unknown transaction status " ^ other
        ^ " (expected INCLUDED/PENDING/UNKNOWN)" )

(* AccountAuthRequired enum — used for every permission field on
   AccountPermissions. *)
type auth_required =
  | NoneAuth (* "None" but avoid clashing with stdlib *)
  | Either
  | Proof
  | Signature
  | Impossible

let auth_required_typ : (Mock_context.t, auth_required option) typ =
  enum "AccountAuthRequired" ~doc:"Kind of authorization required"
    ~values:
      [ enum_value "None" ~value:NoneAuth
      ; enum_value "Either" ~value:Either
      ; enum_value "Proof" ~value:Proof
      ; enum_value "Signature" ~value:Signature
      ; enum_value "Impossible" ~value:Impossible
      ]

(* Encoding enum is defined inline at the [protocolState] arg site
   in [mock_schema.ml] (same pattern as Mina_graphql; see comments there
   for the why). *)
type encoding = JSON_ENC | BASE64_ENC

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

(* ConsensusConfiguration, Peer, AddrsAndPorts, DaemonStatus: produced by
   the shared functor in [Mina_graphql.Types.Make_daemon_status]. See
   [Persona_to_status.build] for the persona-driven adapter. *)

(* ---------- VerificationKeyPermission / AccountPermissions ---------- *)

type mock_vk_permission = { vkp_auth : auth_required; vkp_txn_version : string }

let verification_key_permission :
    (Mock_context.t, mock_vk_permission option) typ =
  obj "VerificationKeyPermission" ~fields:(fun _info ->
      [ field "auth"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (v : mock_vk_permission) -> v.vkp_auth)
      ; field "txnVersion" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (v : mock_vk_permission) -> v.vkp_txn_version)
      ] )

(* AccountPermissions has 13 fields; 12 use AccountAuthRequired and 1
   uses VerificationKeyPermission. The mock returns the default-ish
   permission set for every account: send/receive/access are Signature,
   editState/setDelegate/setPermissions/setVerificationKey/etc. are
   Signature, setVerificationKey is {auth=Signature, txnVersion="3"}. *)
type mock_permissions =
  { perm_edit_state : auth_required
  ; perm_send : auth_required
  ; perm_receive : auth_required
  ; perm_access : auth_required
  ; perm_set_delegate : auth_required
  ; perm_set_permissions : auth_required
  ; perm_set_verification_key : mock_vk_permission
  ; perm_set_zkapp_uri : auth_required
  ; perm_edit_action_state : auth_required
  ; perm_set_token_symbol : auth_required
  ; perm_increment_nonce : auth_required
  ; perm_set_voting_for : auth_required
  ; perm_set_timing : auth_required
  }

let account_permissions : (Mock_context.t, mock_permissions option) typ =
  obj "AccountPermissions" ~fields:(fun _info ->
      [ field "editState"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_edit_state)
      ; field "send"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_send)
      ; field "receive"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_receive)
      ; field "access"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_access)
      ; field "setDelegate"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_delegate)
      ; field "setPermissions"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_permissions)
      ; field "setVerificationKey"
          ~typ:(non_null verification_key_permission)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_verification_key)
      ; field "setZkappUri"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_zkapp_uri)
      ; field "editActionState"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_edit_action_state)
      ; field "setTokenSymbol"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_token_symbol)
      ; field "incrementNonce"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_increment_nonce)
      ; field "setVotingFor"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_voting_for)
      ; field "setTiming"
          ~typ:(non_null auth_required_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_permissions) -> p.perm_set_timing)
      ] )

(* Default permission set for normal (non-zkApp) accounts. *)
let default_permissions : mock_permissions =
  { perm_edit_state = Signature
  ; perm_send = Signature
  ; perm_receive = NoneAuth
  ; perm_access = NoneAuth
  ; perm_set_delegate = Signature
  ; perm_set_permissions = Signature
  ; perm_set_verification_key = { vkp_auth = Signature; vkp_txn_version = "3" }
  ; perm_set_zkapp_uri = Signature
  ; perm_edit_action_state = Signature
  ; perm_set_token_symbol = Signature
  ; perm_increment_nonce = Signature
  ; perm_set_voting_for = Signature
  ; perm_set_timing = Signature
  }

(* ---------- TrustStatusPayload ---------- *)

type mock_trust_status =
  { ts_ip_addr : string
  ; ts_peer_id : string
  ; ts_trust : float
  ; ts_banned_status : string option
  }

let trust_status_payload : (Mock_context.t, mock_trust_status option) typ =
  obj "TrustStatusPayload" ~fields:(fun _info ->
      [ field "ipAddr" ~typ:(non_null inet_addr)
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_trust_status) -> t.ts_ip_addr)
      ; field "peerId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_trust_status) -> t.ts_peer_id)
      ; field "trust" ~typ:(non_null float)
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_trust_status) -> t.ts_trust)
      ; field "bannedStatus" ~typ:time_scalar
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_trust_status) -> t.ts_banned_status)
      ] )

(* ---------- AccountVerificationKeyWithHash ---------- *)

type mock_account_vk = { vk_data : string; vk_hash : string }

let account_verification_key_with_hash :
    (Mock_context.t, mock_account_vk option) typ =
  obj "AccountVerificationKeyWithHash" ~fields:(fun _info ->
      [ field "verificationKey"
          ~typ:(non_null verification_key)
          ~args:Arg.[]
          ~resolve:(fun _ (v : mock_account_vk) -> v.vk_data)
      ; field "hash"
          ~typ:(non_null verification_key_hash)
          ~args:Arg.[]
          ~resolve:(fun _ (v : mock_account_vk) -> v.vk_hash)
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
      [ field "initialMinimumBalance" ~typ:balance_scalar
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_initial_minimum_balance)
      ; field "cliffTime" ~typ:global_slot
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_cliff_time)
      ; field "cliffAmount" ~typ:amount
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_cliff_amount)
      ; field "vestingPeriod" ~typ:global_slot_span
          ~args:Arg.[]
          ~resolve:(fun _ (t : mock_timing) -> t.tim_vesting_period)
      ; field "vestingIncrement" ~typ:amount
          ~args:Arg.[]
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
      [ field "total" ~typ:(non_null balance_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_total)
      ; field "unknown" ~typ:(non_null balance_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_unknown)
      ; field "liquid" ~typ:balance_scalar
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_liquid)
      ; field "locked" ~typ:balance_scalar
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_locked)
      ; field "blockHeight" ~typ:(non_null length_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_balance) -> b.bal_block_height)
      ; field "stateHash" ~typ:state_hash_scalar
          ~args:Arg.[]
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
  ; mock_permissions : mock_permissions
  ; mock_verification_key : mock_account_vk option
  }

let account : (Mock_context.t, mock_account option) typ =
  obj "Account" ~fields:(fun _info ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_public_key)
      ; field "tokenId" ~typ:(non_null token_id)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_token_id)
      ; field "token" ~typ:(non_null token_id) ~doc:"Alias for tokenId"
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
      ; field "balance"
          ~typ:(non_null annotated_balance)
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_balance)
      ; field "timing" ~typ:(non_null account_timing)
          ~args:Arg.[]
          ~resolve:(fun _ (_a : mock_account) -> untimed)
      ; field "permissions" ~typ:account_permissions
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> Some a.mock_permissions)
      ; field "verificationKey" ~typ:account_verification_key_with_hash
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_verification_key)
      ; field "leafHash" ~typ:field_elem
          ~args:Arg.[]
          ~resolve:(fun _ (a : mock_account) -> a.mock_leaf_hash)
      ] )

(** Lookup an account in the persona's [accounts] JSON object by public key.
    Returns a [mock_account] populated from the persona, or None if the key
    isn't known to the canned world. *)
let mock_account_of_persona (persona : Persona.t) ~public_key :
    mock_account option =
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
            ; mock_permissions = default_permissions
            ; mock_verification_key =
                ( match Yojson.Safe.Util.member "zkapp" json with
                | `Assoc _ as zkapp ->
                    let open Yojson.Safe.Util in
                    let vk = zkapp |> member "verificationKey" in
                    let data =
                      match vk |> member "data" with
                      | `String s ->
                          s
                      | _ ->
                          "AACGfBASrjLO9V8yGnt8mockverificationkey="
                    in
                    let hash =
                      match vk |> member "hash" with
                      | `String s ->
                          s
                      | _ ->
                          "0x0123abcd"
                    in
                    Some { vk_data = data; vk_hash = hash }
                | _ ->
                    None )
            } )
  | _ ->
      None

(* ---------- SnarkWorker ---------- *)

(* Placed after Account so [mock_account] and [account] typ are in scope. *)

type mock_snark_worker =
  { sw_key : string (* public key *)
  ; sw_account : mock_account
  ; sw_fee : string
  }

let snark_worker : (Mock_context.t, mock_snark_worker option) typ =
  obj "SnarkWorker" ~fields:(fun _info ->
      [ field "key" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (s : mock_snark_worker) -> s.sw_key)
      ; field "account" ~typ:(non_null account)
          ~args:Arg.[]
          ~resolve:(fun _ (s : mock_snark_worker) -> s.sw_account)
      ; field "fee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~resolve:(fun _ (s : mock_snark_worker) -> s.sw_fee)
      ] )

(* ---------- Block (minimal) ---------- *)

(* v0.1 Block omits the heavy fields: protocolState (3-deep nested object
   tree with BlockchainState + ConsensusState + StakingEpochData etc.),
   protocolStateProof, transactions (would pull in FeeTransfer, ZkappCommand,
   ZkappCommandResult and their deep nesting), and snarkJobs (CompletedWork).
   Those land in follow-up commits as their backing types come online.

   What's exposed today: scalar metadata + the creator/winner accounts,
   which is enough for "browse the latest blocks" demos against bestChain. *)

type mock_block =
  { mb_creator : string (* public key *)
  ; mb_creator_account : mock_account
  ; mb_winner_account : mock_account
  ; mb_state_hash : string
  ; mb_state_hash_field : string
  ; mb_command_transaction_count : int
  }

let block_typ : (Mock_context.t, mock_block option) typ =
  obj "Block" ~fields:(fun _info ->
      [ field "creator" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_creator)
      ; field "creatorAccount" ~typ:(non_null account)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_creator_account)
      ; field "winnerAccount" ~typ:(non_null account)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_winner_account)
      ; field "stateHash"
          ~typ:(non_null state_hash_scalar)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_state_hash)
      ; field "stateHashField"
          ~typ:(non_null state_hash_as_decimal)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_state_hash_field)
      ; field "commandTransactionCount" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (b : mock_block) -> b.mb_command_transaction_count)
      ] )

(* Convert one persona block (raw JSON) to a mock_block. Falls back to
   the persona's block-producer account for creator/winner accounts so
   subset-clean accounts always exist. *)
let mock_block_of_json (persona : Persona.t) (json : Yojson.Safe.t) : mock_block
    =
  let open Yojson.Safe.Util in
  let creator_pk =
    match json |> member "creator" with
    | `String s ->
        s
    | _ ->
        persona.daemon.block_producer_account
  in
  let state_hash =
    match json |> member "stateHash" with `String s -> s | _ -> ""
  in
  let tx_count =
    match json |> member "transactions" with
    | `List xs ->
        List.length xs
    | _ ->
        0
  in
  let bp =
    Option.value
      (mock_account_of_persona persona ~public_key:creator_pk)
      ~default:
        { mock_public_key = creator_pk
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
            ; bal_block_height = string_of_int persona.daemon.blockchain_length
            ; bal_state_hash = persona.daemon.state_hash
            }
        ; mock_leaf_hash = None
        ; mock_permissions = default_permissions
        ; mock_verification_key = None
        }
  in
  { mb_creator = creator_pk
  ; mb_creator_account = bp
  ; mb_winner_account = bp
  ; mb_state_hash = state_hash
  ; mb_state_hash_field = "0"
  ; mb_command_transaction_count = tx_count
  }

(* All blocks from the persona, oldest-first (the JSON is newest-first
   so we reverse). [bestChain] returns suffix of this. *)
let mock_blocks (persona : Persona.t) : mock_block list =
  let entries = match persona.blocks with `List xs -> xs | _ -> [] in
  List.rev_map (mock_block_of_json persona) entries

(* ---------- CompletedWork ---------- *)

type mock_completed_work =
  { cw_prover : string; cw_fee : string; cw_work_ids : int list }

let completed_work : (Mock_context.t, mock_completed_work option) typ =
  obj "CompletedWork" ~fields:(fun _info ->
      [ field "prover" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (w : mock_completed_work) -> w.cw_prover)
      ; field "fee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~resolve:(fun _ (w : mock_completed_work) -> w.cw_fee)
      ; field "workIds"
          ~typ:(non_null (list (non_null int)))
          ~args:Arg.[]
          ~resolve:(fun _ (w : mock_completed_work) -> w.cw_work_ids)
      ] )

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
  ; uc_kind : string (* "PAYMENT" | "STAKE_DELEGATION" | "ZKAPP" *)
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
      ; abstract_field "failureReason" ~typ:transaction_status_failure ~args:[]
      ] )

(* Shared field definitions, reused across all concrete UserCommand impls. *)
let user_command_shared_fields : (Mock_context.t, mock_user_command) field list
    =
  [ field "id" ~typ:(non_null transaction_id)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_id)
  ; field "hash"
      ~typ:(non_null transaction_hash)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_hash)
  ; field "kind"
      ~typ:(non_null user_command_kind)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_kind)
  ; field "nonce" ~typ:(non_null int)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_nonce)
  ; field "source" ~typ:(non_null account)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_source_account)
  ; field "receiver" ~typ:(non_null account)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_receiver_account)
  ; field "feePayer" ~typ:(non_null account)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee_payer_account)
  ; field "validUntil" ~typ:(non_null global_slot)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_valid_until)
  ; field "token" ~typ:(non_null token_id)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_token)
  ; field "amount" ~typ:(non_null amount)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_amount)
  ; field "feeToken" ~typ:(non_null token_id)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee_token)
  ; field "fee" ~typ:(non_null fee)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_fee)
  ; field "memo" ~typ:(non_null string)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_memo)
  ; field "isDelegation" ~typ:(non_null bool)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_is_delegation)
  ; field "from" ~typ:(non_null public_key)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_from_pk)
  ; field "fromAccount" ~typ:(non_null account)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_source_account)
  ; field "to" ~typ:(non_null public_key)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_to_pk)
  ; field "toAccount" ~typ:(non_null account)
      ~args:Arg.[]
      ~resolve:(fun _ (u : mock_user_command) -> u.uc_receiver_account)
  ; field "failureReason" ~typ:transaction_status_failure
      ~args:Arg.[]
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
      "A cryptographic signature -- you must provide either field+scalar or \
       rawSignature"
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
            ~doc:
              "Should only be set when cancelling transactions, otherwise a \
               nonce is determined automatically"
        ; arg "memo" ~typ:string
            ~doc:"Short arbitrary message provided by the sender"
        ; arg "validUntil" ~typ:uint32_arg
            ~doc:
              "The global slot since genesis after which this transaction \
               cannot be applied"
        ; arg "fee" ~typ:(non_null uint64_arg)
            ~doc:"Fee amount in order to send payment"
        ; arg "amount" ~typ:(non_null uint64_arg)
            ~doc:"Amount of MINA to send to receiver"
        ; arg "to" ~typ:(non_null public_key_arg)
            ~doc:"Public key of recipient of payment"
        ; arg "from" ~typ:(non_null public_key_arg)
            ~doc:"Public key of sender of payment"
        ]

(* ---------- SendPaymentPayload ---------- *)

let send_payment_payload : (Mock_context.t, mock_user_command option) typ =
  obj "SendPaymentPayload" ~fields:(fun _ ->
      [ field "payment"
          ~typ:(non_null user_command_interface)
          ~args:Arg.[]
          ~doc:"Payment that has been enqueued for inclusion (mock)"
          ~resolve:(fun _ (u : mock_user_command) -> mk_payment u)
      ] )

(* ---------- Admin mutation inputs/payloads ---------- *)

(* SetSnarkWorker *)
type set_snark_worker_input = { ssw_public_key : string option }

let set_snark_worker_input =
  Arg.obj "SetSnarkWorkerInput"
    ~coerce:(fun pk -> { ssw_public_key = pk })
    ~fields:Arg.[ arg "publicKey" ~typ:public_key_arg ]

let set_snark_worker_payload : (Mock_context.t, string option option) typ =
  obj "SetSnarkWorkerPayload" ~fields:(fun _info ->
      [ field "lastSnarkWorker" ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (last : string option) -> last)
      ] )

(* SetSnarkWorkFee *)
type set_snark_work_fee_input = { ssw_fee_fee : string }

let set_snark_work_fee_input =
  Arg.obj "SetSnarkWorkFee"
    ~coerce:(fun fee -> { ssw_fee_fee = fee })
    ~fields:Arg.[ arg "fee" ~typ:(non_null uint64_arg) ]

let set_snark_work_fee_payload : (Mock_context.t, string option) typ =
  obj "SetSnarkWorkFeePayload" ~fields:(fun _info ->
      [ field "lastFee" ~typ:(non_null fee)
          ~args:Arg.[]
          ~resolve:(fun _ (last : string) -> last)
      ] )

(* SetCoinbaseReceiver *)
type set_coinbase_receiver_input = { scr_public_key : string option }

let set_coinbase_receiver_input =
  Arg.obj "SetCoinbaseReceiverInput"
    ~coerce:(fun pk -> { scr_public_key = pk })
    ~fields:Arg.[ arg "publicKey" ~typ:public_key_arg ]

(* Payload carries both [lastCoinbaseReceiver] and [currentCoinbaseReceiver]. *)
type mock_coinbase_payload =
  { mcb_last : string option; mcb_current : string option }

let set_coinbase_receiver_payload :
    (Mock_context.t, mock_coinbase_payload option) typ =
  obj "SetCoinbaseReceiverPayload" ~fields:(fun _info ->
      [ field "lastCoinbaseReceiver" ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_coinbase_payload) -> p.mcb_last)
      ; field "currentCoinbaseReceiver" ~typ:public_key
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_coinbase_payload) -> p.mcb_current)
      ] )

(* Lock / Unlock — share the same payload shape (publicKey + Account).
   Note: input objects are intentionally minimal; the mock doesn't really
   lock/unlock anything. *)
type lock_input = { lock_public_key : string }

let lock_input_arg =
  Arg.obj "LockInput"
    ~coerce:(fun pk -> { lock_public_key = pk })
    ~fields:Arg.[ arg "publicKey" ~typ:(non_null public_key_arg) ]

type unlock_input = { unlock_public_key : string; unlock_password : string }

let unlock_input_arg =
  Arg.obj "UnlockInput"
    ~coerce:(fun pk pw -> { unlock_public_key = pk; unlock_password = pw })
    ~fields:
      Arg.
        [ arg "publicKey" ~typ:(non_null public_key_arg)
        ; arg "password" ~typ:(non_null string)
        ]

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
      [ field "delegation"
          ~typ:(non_null user_command_interface)
          ~args:Arg.[]
          ~doc:"Delegation that has been enqueued for inclusion (mock)"
          ~resolve:(fun _ (u : mock_user_command) -> mk_payment u)
      ] )

(* ---------- ZkappCommand input tree (minimal) ---------- *)

(* INTENTIONAL SCOPE CUT: AccountUpdateBodyInput in the real schema has
   14 required fields, several of which reference deeply nested input
   objects (AccountUpdateModificationInput, BalanceChangeInput,
   PreconditionsInput, MayUseTokenInput, AuthorizationKindStructuredInput).
   Mocking all of those is multi-day work. v0.1 declares only the simple
   scalar fields the docs playground actually demonstrates; subset
   semantics still holds (mock is a subset of real). Clients writing
   against the real daemon must provide the other fields. *)

type mock_fee_payer_body_input =
  { fpb_public_key : string
  ; fpb_fee : string
  ; fpb_valid_until : string option
  ; fpb_nonce : string
  }

let fee_payer_body_input =
  Arg.obj "FeePayerBodyInput"
    ~coerce:(fun pk fee valid_until nonce ->
      { fpb_public_key = pk
      ; fpb_fee = fee
      ; fpb_valid_until = valid_until
      ; fpb_nonce = nonce
      } )
    ~fields:
      Arg.
        [ arg "publicKey" ~typ:(non_null public_key_arg)
        ; arg "fee" ~typ:(non_null fee_arg)
        ; arg "validUntil" ~typ:global_slot_since_genesis_arg
        ; arg "nonce" ~typ:(non_null uint32_arg)
        ]

type mock_account_update_body_input =
  { aub_public_key : string
  ; aub_token_id : string
  ; aub_call_depth : int
  ; aub_increment_nonce : bool
  ; aub_use_full_commitment : bool
  ; aub_implicit_account_creation_fee : bool
  }

(* v0.1 minimal subset: 6 of 14 real fields, all simple scalars. *)
let account_update_body_input =
  Arg.obj "AccountUpdateBodyInput"
    ~coerce:(fun pk token_id call_depth inc_nonce use_full implicit_fee ->
      { aub_public_key = pk
      ; aub_token_id = token_id
      ; aub_call_depth = call_depth
      ; aub_increment_nonce = inc_nonce
      ; aub_use_full_commitment = use_full
      ; aub_implicit_account_creation_fee = implicit_fee
      } )
    ~fields:
      Arg.
        [ arg "publicKey" ~typ:(non_null public_key_arg)
        ; arg "tokenId" ~typ:(non_null token_id_arg)
        ; arg "callDepth" ~typ:(non_null int)
        ; arg "incrementNonce" ~typ:(non_null bool)
        ; arg "useFullCommitment" ~typ:(non_null bool)
        ; arg "implicitAccountCreationFee" ~typ:(non_null bool)
        ]

type mock_control_input =
  { ci_proof : string option; ci_signature : string option }

let control_input =
  Arg.obj "ControlInput"
    ~coerce:(fun proof signature ->
      { ci_proof = proof; ci_signature = signature } )
    ~fields:
      Arg.
        [ arg "proof" ~typ:zkapp_proof_arg
        ; arg "signature" ~typ:signature_scalar_arg
        ]

type mock_zkapp_fee_payer_input =
  { zfp_body : mock_fee_payer_body_input; zfp_authorization : string }

let zkapp_fee_payer_input =
  Arg.obj "ZkappFeePayerInput"
    ~coerce:(fun body auth -> { zfp_body = body; zfp_authorization = auth })
    ~fields:
      Arg.
        [ arg "body" ~typ:(non_null fee_payer_body_input)
        ; arg "authorization" ~typ:(non_null signature_scalar_arg)
        ]

type mock_zkapp_account_update_input =
  { zau_body : mock_account_update_body_input
  ; zau_authorization : mock_control_input
  }

let zkapp_account_update_input =
  Arg.obj "ZkappAccountUpdateInput"
    ~coerce:(fun body auth -> { zau_body = body; zau_authorization = auth })
    ~fields:
      Arg.
        [ arg "body" ~typ:(non_null account_update_body_input)
        ; arg "authorization" ~typ:(non_null control_input)
        ]

type mock_zkapp_command_input =
  { zci_fee_payer : mock_zkapp_fee_payer_input
  ; zci_account_updates : mock_zkapp_account_update_input list
  ; zci_memo : string
  }

let zkapp_command_input =
  Arg.obj "ZkappCommandInput"
    ~coerce:(fun fp updates memo ->
      { zci_fee_payer = fp; zci_account_updates = updates; zci_memo = memo } )
    ~fields:
      Arg.
        [ arg "feePayer" ~typ:(non_null zkapp_fee_payer_input)
        ; arg "accountUpdates"
            ~typ:(non_null (list (non_null zkapp_account_update_input)))
        ; arg "memo" ~typ:(non_null memo_arg)
        ]

type mock_send_zkapp_input = { szi_zkapp_command : mock_zkapp_command_input }

let send_zkapp_input =
  Arg.obj "SendZkappInput"
    ~coerce:(fun zc -> { szi_zkapp_command = zc })
    ~fields:Arg.[ arg "zkappCommand" ~typ:(non_null zkapp_command_input) ]

(* ---------- ZkappCommand output tree (minimal) ---------- *)

(* ZkappCommandResult.zkappCommand returns the full ZkappCommand object,
   which would require defining ZkappCommand + ZkappFeePayer + ZkappAccountUpdate
   + AccountUpdateBody + FeePayerBody + 10+ nested types. v0.1 omits the
   [zkappCommand] field from our mock ZkappCommandResult — subset semantics
   permits, and the playground demo can query id/hash/failureReason.
   Clients needing the full echo can query the real daemon. *)

type mock_zkapp_failure =
  { zf_index : string option
  ; zf_failures : string list (* TransactionStatusFailure list *)
  }

let zkapp_command_failure_reason :
    (Mock_context.t, mock_zkapp_failure option) typ =
  obj "ZkappCommandFailureReason" ~fields:(fun _info ->
      [ field "index" ~typ:index_scalar
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_failure) -> z.zf_index)
      ; field "failures"
          ~typ:(non_null (list (non_null transaction_status_failure)))
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_failure) -> z.zf_failures)
      ] )

type mock_zkapp_command_result =
  { zcr_id : string
  ; zcr_hash : string
  ; zcr_failure_reason : mock_zkapp_failure list option
  }

let zkapp_command_result :
    (Mock_context.t, mock_zkapp_command_result option) typ =
  obj "ZkappCommandResult" ~fields:(fun _info ->
      [ field "id" ~typ:(non_null transaction_id)
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_command_result) -> z.zcr_id)
      ; field "hash"
          ~typ:(non_null transaction_hash)
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_command_result) -> z.zcr_hash)
      ; field "failureReason"
          ~typ:(list zkapp_command_failure_reason)
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_command_result) ->
            (* Real schema: [ZkappCommandFailureReason] — each element is
               nullable, so we wrap entries in Some. *)
            Option.map (List.map (fun f -> Some f)) z.zcr_failure_reason )
      ] )

let send_zkapp_payload : (Mock_context.t, mock_zkapp_command_result option) typ
    =
  obj "SendZkappPayload" ~fields:(fun _info ->
      [ field "zkapp"
          ~typ:(non_null zkapp_command_result)
          ~args:Arg.[]
          ~resolve:(fun _ (z : mock_zkapp_command_result) -> z)
      ] )

(* LockPayload / UnlockPayload — defined here, after [account] is in scope. *)
type mock_lock_payload = { lp_public_key : string; lp_account : mock_account }

let lock_payload : (Mock_context.t, mock_lock_payload option) typ =
  obj "LockPayload" ~fields:(fun _info ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_lock_payload) -> p.lp_public_key)
      ; field "account" ~typ:(non_null account)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_lock_payload) -> p.lp_account)
      ] )

let unlock_payload : (Mock_context.t, mock_lock_payload option) typ =
  obj "UnlockPayload" ~fields:(fun _info ->
      [ field "publicKey" ~typ:(non_null public_key)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_lock_payload) -> p.lp_public_key)
      ; field "account" ~typ:(non_null account)
          ~args:Arg.[]
          ~resolve:(fun _ (p : mock_lock_payload) -> p.lp_account)
      ] )

(* TODO as resolvers come online:
   - peers / addrs_and_ports / metrics → object types
   - histograms / consensus* → object types
   - timing/balance on Account → AccountTiming, AnnotatedBalance types
   - UserCommandDelegation / UserCommandZkapp (variant impls of UserCommand)
   - Block type (large; needed for bestChain/block/genesisBlock) *)
