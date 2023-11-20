(* test_ledger_application.ml -- code to test application of transactions to a specific ledger *)

open Core_kernel
open Async_kernel
open Mina_ledger
open Mina_base
open Mina_state

let read_privkey privkey_path =
  let password =
    lazy (Secrets.Keypair.Terminal_stdin.prompt_password "Enter password: ")
  in
  match%map Secrets.Keypair.read ~privkey_path ~password with
  | Ok keypair ->
      keypair
  | Error err ->
      eprintf "Could not read the specified keypair: %s\n"
        (Secrets.Privkey_error.to_string err) ;
      exit 1

let mk_tx acc_creation_fee keypair nonce =
  let num_acc_updates = 8 in
  let multispec : Transaction_snark.For_tests.Multiple_transfers_spec.t =
    let fee_payer = None in
    let receivers =
      List.init num_acc_updates ~f:(fun _ ->
          let kp = Signature_lib.Keypair.create () in
          (Signature_lib.Public_key.compress kp.public_key, Currency.Amount.zero) )
    in
    let zkapp_account_keypairs = [] in
    let new_zkapp_account = false in
    let snapp_update = Account_update.Update.dummy in
    let actions = [] in
    let events = [] in
    let call_data = Snark_params.Tick.Field.zero in
    let preconditions = Some Account_update.Preconditions.accept in
    { fee = Currency.Fee.of_mina_int_exn 1
    ; sender = (keypair, nonce)
    ; fee_payer
    ; receivers
    ; amount =
        Currency.Amount.(scale (of_fee acc_creation_fee) num_acc_updates)
        |> Option.value_exn
    ; zkapp_account_keypairs
    ; memo = Signed_command_memo.empty
    ; new_zkapp_account
    ; snapp_update
    ; actions
    ; events
    ; call_data
    ; preconditions
    }
  in
  Transaction_snark.For_tests.multiple_transfers multispec

let test ~privkey_path ~ledger_path ~prev_block_path ~first_partition_slots
    ~no_new_stack ~has_second_partition num_txs =
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let logger = Logger.create () in
  let%bind keypair = read_privkey privkey_path in
  let ledger =
    Ledger.create ~directory_name:ledger_path
      ~depth:constraint_constants.ledger_depth ()
  in
  let init_nonce =
    let account_id = Account_id.of_public_key keypair.public_key in
    let loc =
      Ledger.location_of_account ledger account_id |> Option.value_exn
    in
    let account = Ledger.get ledger loc |> Option.value_exn in
    account.nonce
  in
  let to_nonce =
    Fn.compose (Unsigned.UInt32.add init_nonce) Unsigned.UInt32.of_int
  in
  let prev_block_data = In_channel.read_all prev_block_path in
  let prev_block =
    Binable.of_string (module Mina_block.Stable.Latest) prev_block_data
  in
  let prev_protocol_state =
    Mina_block.header prev_block |> Mina_block.Header.protocol_state
  in
  let prev_protocol_state_body_hash =
    Protocol_state.body prev_protocol_state |> Protocol_state.Body.hash
  in
  let prev_protocol_state_hash =
    (Protocol_state.hashes_with_body ~body_hash:prev_protocol_state_body_hash
       prev_protocol_state )
      .state_hash
  in
  let prev_state_view =
    Protocol_state.body prev_protocol_state
    |> Mina_state.Protocol_state.Body.view
  in
  let mk_txs' = mk_tx constraint_constants.account_creation_fee keypair in
  let fork_slot =
    Option.value_map ~default:Mina_numbers.Global_slot_since_genesis.zero
      ~f:(fun f -> f.genesis_slot)
      constraint_constants.fork
  in
  let global_slot =
    Protocol_state.consensus_state prev_protocol_state
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.succ
    |> Mina_numbers.Global_slot_since_hard_fork.to_int
    |> Mina_numbers.Global_slot_span.of_int
    |> Mina_numbers.Global_slot_since_genesis.add fork_slot
  in
  let zkapps = List.init num_txs ~f:(Fn.compose mk_txs' to_nonce) in
  let pending_coinbase =
    Pending_coinbase.create ~depth:constraint_constants.pending_coinbase_depth
      ()
    |> Or_error.ok_exn
  in
  let zkapps' =
    List.map zkapps ~f:(fun tx ->
        { With_status.data =
            Mina_transaction.Transaction.Command (User_command.Zkapp_command tx)
        ; status = Applied
        } )
  in
  let start = Time.now () in
  let accounts_accessed =
    List.fold_left zkapps ~init:Account_id.Set.empty ~f:(fun set cmd ->
        Account_id.Set.(
          union set (of_list (Zkapp_command.accounts_referenced cmd))) )
  in
  Ledger.unsafe_preload_accounts_from_parent ledger
    (Set.to_list accounts_accessed) ;
  match%map
    Staged_ledger.For_tests.update_coinbase_stack_and_get_data_impl
      ~first_partition_slots ~is_new_stack:(not no_new_stack)
      ~no_second_partition:(not has_second_partition) ~constraint_constants
      ~logger ~global_slot ledger pending_coinbase zkapps' prev_state_view
      (prev_protocol_state_hash, prev_protocol_state_body_hash)
  with
  | Ok (b, _, _, _, _) ->
      printf "Result of application: %B (took %s)\n" b
        Time.(Span.to_string @@ diff (now ()) start) ;
      printf
        !"Database metrics = %{sexp: Rocksdb.Database.Metrics.t}\n"
        Rocksdb.Database.metrics ;
      [ Mina_transaction_logic.Zkapp_command_logic.Metrics.t
      ; Sparse_ledger_lib.Sparse_ledger.Metrics.t
      ]
      |> List.map ~f:Hashtbl.to_alist
      |> List.concat
      |> List.sort ~compare:(fun a b -> Time.Span.compare (snd a) (snd b))
      |> List.iter ~f:(fun (id, span) ->
             printf "%s: %s\n" id (Time.Span.to_string_hum span) )
      (* printf !"Transaction logic metrics = %{sexp: (string * Time.Span.t) list}\n" (Hashtbl.to_alist Mina_transaction_logic.Zkapp_command_logic.Metrics.t) *)
  | Error e ->
      eprintf "Error applying staged ledger: %s\n"
        (Staged_ledger.Staged_ledger_error.to_string e)
