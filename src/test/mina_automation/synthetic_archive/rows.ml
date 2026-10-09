(** Writes a {!Scenario} into an archive database. Every row is
    a [Processor] row record, so the columns follow the archive's own
    types; a column the scenario does not set gets a fixed placeholder. *)

open Core
open Async
open Scenario
module P = Archive_lib.Processor

(* database ids of what was written; blocks by index, commands by hash *)
type ids =
  { blocks : int Int.Table.t
  ; user_commands : int String.Table.t
  ; zkapp_commands : int String.Table.t
  ; coinbases : int String.Table.t
  }

type t =
  { conn : (module Mina_caqti.CONNECTION)
  ; public_key_ids : int String.Table.t
  ; account_identifier_ids : int String.Table.t
  ; sequence_nos : int Int.Table.t
  ; ids : ids
  }

let placeholder = "archive-db-builder"

(* what the archive stores for a command without a memo *)
let empty_memo = Mina_base.Signed_command_memo.(to_base58_check empty)

let insert ?tannot ?(returning = "id") w ~table_name ~cols:(names, typ) ~ctx
    value =
  let (module Conn : Mina_caqti.CONNECTION) = w.conn in
  Conn.find
    (Mina_caqti.find_req typ Caqti_type.int
       (Mina_caqti.insert_into_cols ~returning ~table_name ?tannot ~cols:names
          () ) )
    value
  >>| Mina_caqti.ok_exn ~ctx

(* a row that links a block to a command or account has no id of its own;
   its block_id comes back instead and is dropped *)
let insert_link ?tannot w ~table_name ~cols ~ctx value =
  insert ?tannot ~returning:"block_id" w ~table_name ~cols ~ctx value
  >>| fun (_ : int) -> ()

let transaction_status = function
  | "status" ->
      Some "transaction_status"
  | _ ->
      None

let chain_status_text = function
  | Canonical ->
      "canonical"
  | Orphaned ->
      "orphaned"
  | Pending ->
      "pending"

let status_and_reason = function
  | Applied ->
      ("applied", None)
  | Failed reason ->
      ("failed", Some reason)

let public_key_id w (a : account) = Hashtbl.find_exn w.public_key_ids a.pk

let account_identifier_id w (a : account) =
  Hashtbl.find_exn w.account_identifier_ids a.pk

let block_id w b = Hashtbl.find_exn w.ids.blocks b.index

(* user commands first in each block, then zkApp commands, then coinbases:
   the order they are written in *)
let next_sequence_no w b =
  let n = Option.value (Hashtbl.find w.sequence_nos b.index) ~default:0 in
  Hashtbl.set w.sequence_nos ~key:b.index ~data:(n + 1) ;
  n

(* a scenario goes into an archive with no blocks *)
let ensure_no_blocks w ~db_name =
  let (module Conn : Mina_caqti.CONNECTION) = w.conn in
  let%map existing =
    Conn.find
      (Mina_caqti.find_req Caqti_type.unit Caqti_type.int
         "SELECT count(*)::int FROM blocks" )
      ()
    >>| Mina_caqti.ok_exn ~ctx:"existing blocks"
  in
  if existing > 0 then
    failwithf "archive %s already has %d blocks" db_name existing ()

(* --- accounts ---------------------------------------------------------------- *)

let write_default_token w =
  insert w ~table_name:P.Token.table_name
    ~cols:(P.Token.Fields.names, P.Token.typ)
    ~ctx:"token"
    { value = Mina_base.Token_id.(to_string default)
    ; owner_public_key_id = None
    ; owner_token_id = None
    }

let write_account w ~token_id (a : account) =
  let%bind public_key_id =
    insert w ~table_name:"public_keys"
      ~cols:([ "value" ], Caqti_type.string)
      ~ctx:("public key of " ^ a.account_name)
      a.pk
  in
  let%map account_identifier_id =
    insert w ~table_name:P.Account_identifiers.table_name
      ~cols:(P.Account_identifiers.Fields.names, P.Account_identifiers.typ)
      ~ctx:("account identifier of " ^ a.account_name)
      { public_key_id; token_id }
  in
  Hashtbl.set w.public_key_ids ~key:a.pk ~data:public_key_id ;
  Hashtbl.set w.account_identifier_ids ~key:a.pk ~data:account_identifier_id

let write_accounts w accounts =
  let%bind token_id = write_default_token w in
  Deferred.List.iter ~how:`Sequential accounts ~f:(write_account w ~token_id)

(* --- blocks ------------------------------------------------------------------ *)

(* the ledger and epoch rows every block points at *)
type block_context =
  { snarked_ledger_hash_id : int
  ; epoch_data_id : int
  ; protocol_version_ids : (int * int * int, int) Hashtbl.t
  ; producer : account
  }

let write_epoch_data w =
  let%bind ledger_hash_id =
    insert w ~table_name:"snarked_ledger_hashes"
      ~cols:([ "value" ], Caqti_type.string)
      ~ctx:"snarked ledger hash" placeholder
  in
  let%map epoch_data_id =
    insert w ~table_name:"epoch_data"
      ~cols:(P.Epoch_data.Fields.names, P.Epoch_data.typ)
      ~ctx:"epoch data"
      { seed = placeholder
      ; ledger_hash_id
      ; total_currency = "0"
      ; start_checkpoint = placeholder
      ; lock_checkpoint = placeholder
      ; epoch_length = 1L
      }
  in
  (ledger_hash_id, epoch_data_id)

(* ascending, so that ids follow versions *)
let write_protocol_versions w blocks =
  let ids = Hashtbl.Poly.create () in
  let write ((transaction, network, patch) as version) =
    let%map id =
      insert w ~table_name:P.Protocol_versions.table_name
        ~cols:(P.Protocol_versions.Fields.names, P.Protocol_versions.typ)
        ~ctx:"protocol version"
        { transaction; network; patch }
    in
    Hashtbl.set ids ~key:version ~data:id
  in
  let%map () =
    List.map blocks ~f:(fun b -> b.protocol_version)
    |> List.dedup_and_sort ~compare:[%compare: int * int * int]
    |> Deferred.List.iter ~how:`Sequential ~f:write
  in
  ids

let block_row w ctx b : P.Block.t =
  let creator_id =
    public_key_id w (Option.value b.creator ~default:ctx.producer)
  in
  { state_hash = b.block_hash
  ; parent_id = Option.map b.parent ~f:(block_id w)
  ; parent_hash = b.parent_hash
  ; creator_id
  ; block_winner_id = creator_id
  ; last_vrf_output = placeholder
  ; snarked_ledger_hash_id = ctx.snarked_ledger_hash_id
  ; staking_epoch_data_id = ctx.epoch_data_id
  ; next_epoch_data_id = ctx.epoch_data_id
  ; min_window_density = 0L
  ; sub_window_densities = [||]
  ; total_currency = "0"
  ; ledger_hash = placeholder
  ; height = Int64.of_int b.height
  ; global_slot_since_hard_fork = Int64.of_int b.slot_since_hard_fork
  ; global_slot_since_genesis = Int64.of_int b.slot_since_genesis
  ; protocol_version_id =
      Hashtbl.find_exn ctx.protocol_version_ids b.protocol_version
  ; proposed_protocol_version_id = None
  ; timestamp = Int64.to_string b.timestamp
  ; chain_status = chain_status_text b.chain_status
  }

let write_block w ctx b =
  let%map id =
    insert w ~table_name:P.Block.table_name
      ~cols:(P.Block.Fields.names, P.Block.typ)
      ~tannot:(function
        | "chain_status" ->
            Some "chain_status_type"
        | "sub_window_densities" ->
            Some "bigint[]"
        | _ ->
            None )
      ~ctx:("block " ^ b.block_name) (block_row w ctx b)
  in
  Hashtbl.set w.ids.blocks ~key:b.index ~data:id

(* parents first: a parent is always an earlier block of the scenario *)
let write_blocks w (scenario : Scenario.t) =
  let%bind snarked_ledger_hash_id, epoch_data_id = write_epoch_data w in
  let%bind protocol_version_ids = write_protocol_versions w scenario.blocks in
  let ctx =
    { snarked_ledger_hash_id
    ; epoch_data_id
    ; protocol_version_ids
    ; producer = scenario.producer
    }
  in
  Deferred.List.iter ~how:`Sequential scenario.blocks ~f:(write_block w ctx)

(* --- user commands ----------------------------------------------------------- *)

let user_command_row w c : P.User_command.Signed_command.t =
  { command_type =
      (match c.kind with `Payment -> "payment" | `Delegation -> "delegation")
  ; fee_payer_id = public_key_id w c.fee_payer
  ; source_id = public_key_id w c.source
  ; receiver_id = public_key_id w c.receiver
  ; nonce = Int64.of_int c.nonce
  ; amount = Option.map c.amount ~f:Int.to_string
  ; fee = Int.to_string c.fee
  ; valid_until = None
  ; memo = empty_memo
  ; hash = c.command_hash
  }

let write_user_command_inclusion w c ~user_command_id (b, status) =
  let module R = P.Block_and_signed_command in
  let status, failure_reason = status_and_reason status in
  insert_link w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~tannot:transaction_status
    ~ctx:("inclusion of " ^ c.command_name)
    { block_id = block_id w b
    ; user_command_id
    ; sequence_no = next_sequence_no w b
    ; status
    ; failure_reason
    }

let write_user_command w c =
  let module R = P.User_command.Signed_command in
  let%bind user_command_id =
    insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
      ~tannot:(function "command_type" -> Some "user_command_type" | _ -> None)
      ~ctx:("user command " ^ c.command_name)
      (user_command_row w c)
  in
  Hashtbl.set w.ids.user_commands ~key:c.command_hash ~data:user_command_id ;
  Deferred.List.iter ~how:`Sequential c.inclusions
    ~f:(write_user_command_inclusion w c ~user_command_id)

(* --- zkApp commands ---------------------------------------------------------- *)

(* the parts of an account update the builder leaves empty, shared by all *)
type empty_account_update_parts =
  { update_id : int
  ; call_data_id : int
  ; network_precondition_id : int
  ; account_precondition_id : int
  }

let write_empty_state w =
  let module R = P.Zkapp_states_nullable in
  insert w ~table_name:R.table_name ~cols:(R.names, R.typ) ~ctx:"zkapp state"
    (Pickles_types.Vector.of_list_and_length_exn
       (List.init Mina_base.Zkapp_state.max_size_int ~f:(fun _ -> None))
       Mina_base.Zkapp_state.Max_state_size.n )

(* an epoch precondition that accepts any epoch *)
let write_any_epoch_data w =
  let%bind epoch_ledger_id =
    insert w ~table_name:P.Zkapp_epoch_ledger.table_name
      ~cols:(P.Zkapp_epoch_ledger.Fields.names, P.Zkapp_epoch_ledger.typ)
      ~ctx:"zkapp epoch ledger"
      { hash_id = None; total_currency_id = None }
  in
  insert w ~table_name:P.Zkapp_epoch_data.table_name
    ~cols:(P.Zkapp_epoch_data.Fields.names, P.Zkapp_epoch_data.typ)
    ~ctx:"zkapp epoch data"
    { epoch_ledger_id
    ; epoch_seed = None
    ; start_checkpoint = None
    ; lock_checkpoint = None
    ; epoch_length_id = None
    }

let write_network_precondition w =
  let module R = P.Zkapp_network_precondition in
  let%bind epoch_data_id = write_any_epoch_data w in
  insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~ctx:"network precondition"
    { snarked_ledger_hash_id = None
    ; blockchain_length_id = None
    ; min_window_density_id = None
    ; total_currency_id = None
    ; global_slot_since_genesis = None
    ; staking_epoch_data_id = epoch_data_id
    ; next_epoch_data_id = epoch_data_id
    }

let write_account_precondition w ~state_id =
  let module R = P.Zkapp_account_precondition in
  insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~ctx:"account precondition"
    { balance_id = None
    ; nonce_id = None
    ; receipt_chain_hash = None
    ; delegate_id = None
    ; state_id
    ; action_state_id = None
    ; proved_state = None
    ; is_new = None
    }

let write_update w ~app_state_id =
  let module R = P.Zkapp_updates in
  insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~ctx:"zkapp update"
    { app_state_id
    ; delegate_id = None
    ; verification_key_id = None
    ; permissions_id = None
    ; zkapp_uri_id = None
    ; token_symbol_id = None
    ; timing_id = None
    ; voting_for_id = None
    }

let write_empty_account_update_parts w =
  let%bind state_id = write_empty_state w in
  let%bind call_data_id =
    insert w ~table_name:"zkapp_field"
      ~cols:([ "field" ], Caqti_type.string)
      ~ctx:"zkapp field" "0"
  in
  let%bind network_precondition_id = write_network_precondition w in
  let%bind account_precondition_id = write_account_precondition w ~state_id in
  let%map update_id = write_update w ~app_state_id:state_id in
  { update_id; call_data_id; network_precondition_id; account_precondition_id }

let account_update_body_row w parts (u : account_update) :
    P.Zkapp_account_update_body.t =
  { account_identifier_id = account_identifier_id w u.update_account
  ; update_id = parts.update_id
  ; balance_change = Int.to_string u.balance_change
  ; increment_nonce = false
  ; events_id = None
  ; actions_id = None
  ; call_data_id = parts.call_data_id
  ; call_depth = 0
  ; zkapp_network_precondition_id = parts.network_precondition_id
  ; zkapp_account_precondition_id = parts.account_precondition_id
  ; zkapp_valid_while_precondition_id = None
  ; use_full_commitment = false
  ; implicit_account_creation_fee = u.implicit_fee
  ; may_use_token = "No"
  ; authorization_kind = "None_given"
  ; verification_key_hash_id = None
  }

let write_account_update w parts u =
  let module Body = P.Zkapp_account_update_body in
  let%bind body_id =
    insert w ~table_name:Body.table_name
      ~cols:(Body.Fields.names, Body.typ)
      ~tannot:(function
        | "may_use_token" ->
            Some "may_use_token"
        | "authorization_kind" ->
            Some "authorization_kind_type"
        | _ ->
            None )
      ~ctx:"account update body"
      (account_update_body_row w parts u)
  in
  insert w ~table_name:P.Zkapp_account_update.table_name
    ~cols:(P.Zkapp_account_update.Fields.names, P.Zkapp_account_update.typ)
    ~ctx:"account update" { body_id }

(* equal account updates share one row, as in the archive *)
let account_update_writer w parts =
  let ids = Hashtbl.Poly.create () in
  fun (u : account_update) ->
    let key = (u.update_account.pk, u.balance_change, u.implicit_fee) in
    match Hashtbl.find ids key with
    | Some id ->
        return id
    | None ->
        let%map id = write_account_update w parts u in
        Hashtbl.set ids ~key ~data:id ;
        id

(* a failed inclusion records its reason as the first account update's: index
   0 is the fee payer, account updates start at 1 *)
let write_failure w reason =
  let module R = P.Zkapp_account_update_failures in
  insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~tannot:(function "failures" -> Some "text[]" | _ -> None)
    ~ctx:"failure"
    { index = 1; failures = [| reason |] }

let write_zkapp_inclusion w c ~zkapp_command_id (b, status) =
  let module R = P.Block_and_zkapp_command in
  let%bind status, failure_reasons_ids =
    match status with
    | Applied ->
        return ("applied", None)
    | Failed reason ->
        let%map failure_id = write_failure w reason in
        ("failed", Some [| failure_id |])
  in
  insert_link w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~tannot:(function
      | "failure_reasons_ids" -> Some "int[]" | col -> transaction_status col )
    ~ctx:("inclusion of " ^ c.zkapp_name)
    { block_id = block_id w b
    ; zkapp_command_id
    ; sequence_no = next_sequence_no w b
    ; status
    ; failure_reasons_ids
    }

let write_zkapp_command w ~write_account_update c =
  let module R = P.User_command.Zkapp_command in
  let%bind zkapp_fee_payer_body_id =
    insert w ~table_name:P.Zkapp_fee_payer_body.table_name
      ~cols:(P.Zkapp_fee_payer_body.Fields.names, P.Zkapp_fee_payer_body.typ)
      ~ctx:("fee payer of " ^ c.zkapp_name)
      { public_key_id = public_key_id w c.zkapp_fee_payer
      ; fee = Int.to_string c.zkapp_fee
      ; valid_until = None
      ; nonce = Int64.of_int c.zkapp_nonce
      }
  in
  let%bind account_update_ids =
    Deferred.List.map ~how:`Sequential c.account_updates ~f:write_account_update
  in
  let%bind zkapp_command_id =
    insert w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
      ~tannot:(function
        | "zkapp_account_updates_ids" -> Some "int[]" | _ -> None )
      ~ctx:("zkapp command " ^ c.zkapp_name)
      { zkapp_fee_payer_body_id
      ; zkapp_account_updates_ids = Array.of_list account_update_ids
      ; memo = empty_memo
      ; hash = c.zkapp_hash
      }
  in
  Hashtbl.set w.ids.zkapp_commands ~key:c.zkapp_hash ~data:zkapp_command_id ;
  Deferred.List.iter ~how:`Sequential c.zkapp_inclusions
    ~f:(write_zkapp_inclusion w c ~zkapp_command_id)

let write_zkapp_commands w = function
  | [] ->
      return ()
  | commands ->
      let%bind parts = write_empty_account_update_parts w in
      let write_account_update = account_update_writer w parts in
      Deferred.List.iter ~how:`Sequential commands
        ~f:(write_zkapp_command w ~write_account_update)

(* --- internal commands and created accounts ---------------------------------- *)

let write_coinbase w c =
  let%bind internal_command_id =
    insert w ~table_name:P.Internal_command.table_name
      ~cols:(P.Internal_command.Fields.names, P.Internal_command.typ)
      ~tannot:(function
        | "command_type" -> Some "internal_command_type" | _ -> None )
      ~ctx:("coinbase " ^ c.coinbase_name)
      { command_type = "coinbase"
      ; receiver_id = public_key_id w c.coinbase_receiver
      ; fee = Int.to_string c.coinbase_amount
      ; hash = coinbase_hash c
      }
  in
  Hashtbl.set w.ids.coinbases ~key:(coinbase_hash c) ~data:internal_command_id ;
  let module R = P.Block_and_internal_command in
  insert_link w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~tannot:transaction_status
    ~ctx:("inclusion of " ^ c.coinbase_name)
    { block_id = block_id w c.coinbase_block
    ; internal_command_id
    ; sequence_no = next_sequence_no w c.coinbase_block
    ; secondary_sequence_no = 0
    ; status = "applied"
    ; failure_reason = None
    }

let write_account_created w { created_in; created; fee } =
  let module R = P.Accounts_created in
  insert_link w ~table_name:R.table_name ~cols:(R.Fields.names, R.typ)
    ~ctx:("account created " ^ created.account_name)
    { block_id = block_id w created_in
    ; account_identifier_id = account_identifier_id w created
    ; creation_fee = Int.to_string fee
    }

(* the ledger account a state describes *)
let account_of_state
    { state_of
    ; state_balance = balance
    ; state_nonce = nonce
    ; state_timing = timing
    } =
  let account_id =
    Mina_base.Account_id.create
      (Signature_lib.Public_key.Compressed.of_base58_check_exn state_of.pk)
      Mina_base.Token_id.default
  in
  let balance = Currency.Balance.of_nanomina_int_exn balance in
  let account =
    match timing with
    | None ->
        Mina_base.Account.create account_id balance
    | Some tm ->
        Mina_base.Account.create_timed account_id balance
          ~initial_minimum_balance:
            (Currency.Balance.of_nanomina_int_exn tm.initial_minimum_balance)
          ~cliff_time:
            (Mina_numbers.Global_slot_since_genesis.of_int tm.cliff_time)
          ~cliff_amount:(Currency.Amount.of_nanomina_int_exn tm.cliff_amount)
          ~vesting_period:
            (Mina_numbers.Global_slot_span.of_int tm.vesting_period)
          ~vesting_increment:
            (Currency.Amount.of_nanomina_int_exn tm.vesting_increment)
        |> Or_error.ok_exn
  in
  { account with nonce = Mina_base.Account.Nonce.of_int nonce }

(* written by the archive's own accounts_accessed writer, with the rows it
   needs: token symbol, voting for, timing (zeros when untimed), permissions *)
let write_account_state w (block, state) =
  (* no read a test makes depends on the ledger index *)
  let ledger_index = 0 in
  P.Accounts_accessed.add_if_doesn't_exist w.conn (block_id w block)
    (ledger_index, account_of_state state)
  >>| Mina_caqti.ok_exn ~ctx:("state of " ^ state.state_of.account_name)
  >>| fun (_ : int * int) -> ()

(* --- the whole scenario ------------------------------------------------------ *)

let write_all w (scenario : Scenario.t) =
  let%bind () = write_accounts w scenario.accounts in
  let%bind () = write_blocks w scenario in
  let%bind () =
    Deferred.List.iter ~how:`Sequential scenario.user_commands
      ~f:(write_user_command w)
  in
  let%bind () = write_zkapp_commands w scenario.zkapp_commands in
  let%bind () =
    Deferred.List.iter ~how:`Sequential scenario.coinbases ~f:(write_coinbase w)
  in
  let%bind () =
    Deferred.List.iter ~how:`Sequential scenario.accounts_created
      ~f:(write_account_created w)
  in
  Deferred.List.iter ~how:`Sequential scenario.account_states
    ~f:(write_account_state w)

(** Writes [scenario] into the database at [uri] and returns the database
    ids of what it wrote. *)
let write (scenario : Scenario.t) ~uri ~db_name =
  Deferred.Or_error.try_with_join (fun () ->
      let%bind conn =
        Mina_caqti.connect uri >>| Mina_caqti.ok_exn ~ctx:"connect"
      in
      let w =
        { conn
        ; public_key_ids = String.Table.create ()
        ; account_identifier_ids = String.Table.create ()
        ; sequence_nos = Int.Table.create ()
        ; ids =
            { blocks = Int.Table.create ()
            ; user_commands = String.Table.create ()
            ; zkapp_commands = String.Table.create ()
            ; coinbases = String.Table.create ()
            }
        }
      in
      let (module Conn : Mina_caqti.CONNECTION) = conn in
      (* the connection is closed whatever happens, or a failed write would
         keep the database busy and the caller could not drop it *)
      Monitor.protect ~finally:Conn.disconnect (fun () ->
          let%bind () = ensure_no_blocks w ~db_name in
          let%map () = write_all w scenario in
          Ok w.ids ) )
