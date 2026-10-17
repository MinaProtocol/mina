(** The chain content a test describes; {!Rows} turns it into archive
    rows. Use it through {!Synthetic_archive}. *)

open Core

type chain_status = Canonical | Orphaned | Pending

type command_status = Applied | Failed of string

type account = { account_name : string; pk : string }

type block =
  { index : int
  ; block_name : string
  ; block_hash : string
  ; parent : block option
  ; parent_hash : string
  ; height : int
  ; slot_since_genesis : int
  ; slot_since_hard_fork : int
  ; protocol_version : int * int * int
  ; timestamp : int64
  ; creator : account option
  ; chain_status : chain_status
  }

type user_command =
  { command_name : string
  ; kind : [ `Payment | `Delegation ]
  ; fee_payer : account
  ; source : account
  ; receiver : account
  ; amount : int option
  ; fee : int
  ; nonce : int
  ; command_hash : string
  ; inclusions : (block * command_status) list
  }

type account_update =
  { update_account : account; balance_change : int; implicit_fee : bool }

type zkapp_command =
  { zkapp_name : string
  ; zkapp_fee_payer : account
  ; zkapp_fee : int
  ; zkapp_nonce : int
  ; zkapp_hash : string
  ; account_updates : account_update list
  ; zkapp_inclusions : (block * command_status) list
  }

type coinbase =
  { coinbase_name : string
  ; coinbase_receiver : account
  ; coinbase_amount : int
  ; coinbase_block : block
  }

type account_created = { created_in : block; created : account; fee : int }

type timing =
  { initial_minimum_balance : int
  ; cliff_time : int
  ; cliff_amount : int
  ; vesting_period : int
  ; vesting_increment : int
  }

(* the state of an account an archive row records: in a block's
   accounts_accessed, or in a genesis ledger *)
type account_state =
  { state_of : account
  ; state_balance : int
  ; state_nonce : int
  ; state_timing : timing option
  }

type genesis_account = { genesis_height : int; genesis_state : account_state }

type t =
  { producer : account  (** creates every block without a [creator] *)
  ; mutable accounts : account list
  ; mutable blocks : block list
  ; mutable user_commands : user_command list
  ; mutable zkapp_commands : zkapp_command list
  ; mutable coinbases : coinbase list
  ; mutable accounts_created : account_created list
  ; mutable account_states : (block * account_state) list
  ; mutable genesis_accounts : genesis_account list
  ; nonces : int String.Table.t
  ; mutable materialized : bool
  }

let digest s = Md5.digest_string s |> Md5.to_hex

let public_key_of_name name =
  let keypair =
    Quickcheck.random_value
      ~seed:(`Deterministic ("account:" ^ name))
      Signature_lib.Keypair.gen
  in
  Signature_lib.Public_key.(
    compress keypair.public_key |> Compressed.to_base58_check)

let new_account name = { account_name = name; pk = public_key_of_name name }

let create () =
  let producer = new_account "archive-db-builder:block-producer" in
  { producer
  ; accounts = [ producer ]
  ; blocks = []
  ; user_commands = []
  ; zkapp_commands = []
  ; coinbases = []
  ; accounts_created = []
  ; account_states = []
  ; genesis_accounts = []
  ; nonces = String.Table.create ()
  ; materialized = false
  }

let account t name =
  match List.find t.accounts ~f:(fun a -> String.equal a.account_name name) with
  | Some a ->
      a
  | None ->
      let a = new_account name in
      t.accounts <- t.accounts @ [ a ] ;
      a

let public_key a = a.pk

(* block_window_duration of the mainnet and devnet profiles *)
let slot_duration_ms = 90_000L

(* an arbitrary fixed genesis *)
let genesis_timestamp_ms = 1_700_000_000_000L

let timestamp_of_slot slot =
  Int64.(genesis_timestamp_ms + (of_int slot * slot_duration_ms))

let parent_hash_of ~name ~parent ~parent_hash =
  match (parent_hash, parent) with
  | Some hash, _ ->
      hash
  | None, Some p ->
      p.block_hash
  | None, None ->
      "3N" ^ digest ("parent-of:" ^ name)

let block ?state_hash ?parent ?parent_hash ?global_slot_since_genesis
    ?global_slot_since_hard_fork ?(protocol_version = (4, 0, 0)) ?timestamp
    ?creator t ~name ~height chain_status =
  let slot_since_genesis =
    Option.value global_slot_since_genesis ~default:(height - 1)
  in
  let block =
    { index = List.length t.blocks
    ; block_name = name
    ; block_hash =
        Option.value state_hash ~default:("3N" ^ digest ("block:" ^ name))
    ; parent
    ; parent_hash = parent_hash_of ~name ~parent ~parent_hash
    ; height
    ; slot_since_genesis
    ; slot_since_hard_fork =
        Option.value global_slot_since_hard_fork ~default:slot_since_genesis
    ; protocol_version
    ; timestamp =
        Option.value timestamp ~default:(timestamp_of_slot slot_since_genesis)
    ; creator
    ; chain_status
    }
  in
  t.blocks <- t.blocks @ [ block ] ;
  block

let state_hash b = b.block_hash

let next_nonce t (a : account) =
  let n = Option.value (Hashtbl.find t.nonces a.pk) ~default:0 in
  Hashtbl.set t.nonces ~key:a.pk ~data:(n + 1) ;
  n

let add_user_command t ~kind ~fee_payer ~source ~receiver ~amount ~fee ~name
    ~in_ =
  let c =
    { command_name = name
    ; kind
    ; fee_payer
    ; source
    ; receiver
    ; amount
    ; fee
    ; nonce = next_nonce t fee_payer
    ; command_hash = "Ckp" ^ digest ("command:" ^ name)
    ; inclusions = in_
    }
  in
  t.user_commands <- t.user_commands @ [ c ] ;
  c

let payment ?fee_payer ?(amount = 1_000_000_000) ?(fee = 10_000_000) t ~name
    ~source ~receiver ~in_ =
  add_user_command t ~kind:`Payment
    ~fee_payer:(Option.value fee_payer ~default:source)
    ~source ~receiver ~amount:(Some amount) ~fee ~name ~in_

let delegation ?fee_payer ?(fee = 10_000_000) t ~name ~delegator ~delegate ~in_
    =
  add_user_command t ~kind:`Delegation
    ~fee_payer:(Option.value fee_payer ~default:delegator)
    ~source:delegator ~receiver:delegate ~amount:None ~fee ~name ~in_

let user_command_hash c = c.command_hash

let coinbase ?(amount = 720_000_000_000) t ~name ~receiver block =
  let c =
    { coinbase_name = name
    ; coinbase_receiver = receiver
    ; coinbase_amount = amount
    ; coinbase_block = block
    }
  in
  t.coinbases <- t.coinbases @ [ c ] ;
  c

let coinbase_hash c = "Ckp" ^ digest ("coinbase:" ^ c.coinbase_name)

let account_update ?(balance_change = 0)
    ?(implicit_account_creation_fee = false) update_account =
  { update_account
  ; balance_change
  ; implicit_fee = implicit_account_creation_fee
  }

let zkapp_command ?(fee = 10_000_000) t ~name ~fee_payer ~account_updates ~in_ =
  let c =
    { zkapp_name = name
    ; zkapp_fee_payer = fee_payer
    ; zkapp_fee = fee
    ; zkapp_nonce = next_nonce t fee_payer
    ; zkapp_hash = "5Ju" ^ digest ("zkapp:" ^ name)
    ; account_updates
    ; zkapp_inclusions = in_
    }
  in
  t.zkapp_commands <- t.zkapp_commands @ [ c ] ;
  c

let zkapp_command_hash c = c.zkapp_hash

let account_created ?(fee = 1_000_000_000) t block account =
  t.accounts_created <-
    t.accounts_created @ [ { created_in = block; created = account; fee } ]

let account_state ?(nonce = 0) ?timing t block account ~balance =
  t.account_states <-
    t.account_states
    @ [ ( block
        , { state_of = account
          ; state_balance = balance
          ; state_nonce = nonce
          ; state_timing = timing
          } )
      ]

let genesis_account ?(nonce = 0) ?timing t ~genesis_height account ~balance =
  t.genesis_accounts <-
    t.genesis_accounts
    @ [ { genesis_height
        ; genesis_state =
            { state_of = account
            ; state_balance = balance
            ; state_nonce = nonce
            ; state_timing = timing
            }
        }
      ]
