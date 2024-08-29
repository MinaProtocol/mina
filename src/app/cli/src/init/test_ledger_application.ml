(* test_ledger_application.ml -- code to test application of transactions to a specific ledger *)

open Core_kernel
open Async_kernel
open Mina_ledger
open Mina_base
open Mina_state

let logger = Logger.create ()

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

let generate_event =
  Snark_params.Tick.Field.gen |> Quickcheck.Generator.map ~f:(fun x -> [| x |])

let mk_tx
    ~genesis_constants:
      ({ max_event_elements; max_action_elements; _ } : Genesis_constants.t)
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) keypair
    nonce =
  let num_acc_updates = 8 in
  let multispec : Transaction_snark.For_tests.Multiple_transfers_spec.t =
    let fee_payer = None in
    let generated_values =
      let open Base_quickcheck.Generator.Let_syntax in
      let%bind receivers =
        Base_quickcheck.Generator.list_with_length ~length:num_acc_updates
        @@ let%map kp = Signature_lib.Keypair.gen in
           ( Signature_lib.Public_key.compress kp.public_key
           , Currency.Amount.zero )
      in
      let%bind events =
        Quickcheck.Generator.list_with_length max_event_elements generate_event
      in
      let%map actions =
        Quickcheck.Generator.list_with_length max_action_elements generate_event
      in
      (receivers, events, actions)
    in
    let receivers, events, actions =
      Quickcheck.random_value
        ~seed:(`Deterministic ("test-apply-" ^ Unsigned.UInt32.to_string nonce))
        generated_values
    in
    let zkapp_account_keypairs = [] in
    let new_zkapp_account = false in
    let snapp_update = Account_update.Update.dummy in
    let call_data = Snark_params.Tick.Field.zero in
    let preconditions = Some Account_update.Preconditions.accept in
    { fee = Currency.Fee.of_mina_int_exn 1
    ; sender = (keypair, nonce)
    ; fee_payer
    ; receivers
    ; amount =
        Currency.Amount.(
          scale
            (of_fee constraint_constants.account_creation_fee)
            num_acc_updates)
        |> Option.value_exn ~here:[%here]
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
  Transaction_snark.For_tests.multiple_transfers ~constraint_constants multispec

let generate_protocol_state_stub ~consensus_constants ~constraint_constants
    ledger =
  let open Staged_ledger_diff in
  Protocol_state.negative_one
    ~genesis_ledger:(lazy ledger)
    ~genesis_epoch_data:None ~constraint_constants ~consensus_constants
    ~genesis_body_reference

let apply_txs ~genesis_constants ~constraint_constants ~first_partition_slots
    ~no_new_stack ~has_second_partition ~num_txs ~prev_protocol_state
    ~(keypair : Signature_lib.Keypair.t) ~i ledger =
  let init_nonce =
    let account_id = Account_id.of_public_key keypair.public_key in
    let loc =
      Ledger.location_of_account ledger account_id
      |> Option.value_exn ~here:[%here]
    in
    let account = Ledger.get ledger loc |> Option.value_exn ~here:[%here] in
    account.nonce
  in
  let to_nonce =
    Fn.compose (Unsigned.UInt32.add init_nonce) Unsigned.UInt32.of_int
  in
  let mk_tx' = mk_tx ~genesis_constants ~constraint_constants keypair in
  let fork_slot =
    Option.value_map ~default:Mina_numbers.Global_slot_since_genesis.zero
      ~f:(fun f -> f.global_slot_since_genesis)
      constraint_constants.fork
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
  let global_slot =
    Protocol_state.consensus_state prev_protocol_state
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.succ
    |> Mina_numbers.Global_slot_since_hard_fork.to_int
    |> Mina_numbers.Global_slot_span.of_int
    |> Mina_numbers.Global_slot_since_genesis.add fork_slot
  in
  let zkapps = List.init num_txs ~f:(Fn.compose mk_tx' to_nonce) in
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
  let accounts_accessed =
    List.fold_left ~init:Account_id.Set.empty zkapps ~f:(fun set txn ->
        Account_id.Set.(
          union set (of_list (Zkapp_command.accounts_referenced txn))) )
    |> Set.to_list
  in
  Ledger.unsafe_preload_accounts_from_parent ledger accounts_accessed ;
  let start = Time.now () in
  match%map
    Staged_ledger.Test_helpers.update_coinbase_stack_and_get_data_impl
      ~first_partition_slots ~is_new_stack:(not no_new_stack)
      ~no_second_partition:(not has_second_partition) ~constraint_constants
      ~logger ~global_slot ledger pending_coinbase zkapps' prev_state_view
      (prev_protocol_state_hash, prev_protocol_state_body_hash)
  with
  | Ok (b, _, _, _, _) ->
      let root = Ledger.merkle_root ledger in
      printf
        !"Result of application %d: %B (took %s): new root %s\n%!"
        i b
        Time.(Span.to_string @@ diff (now ()) start)
        (Ledger_hash.to_base58_check root)
  | Error e ->
      eprintf
        !"Error applying staged ledger: %s\n%!"
        (Staged_ledger.Staged_ledger_error.to_string e) ;
      exit 1

let test ~privkey_path ~ledger_path ?prev_block_path ~first_partition_slots
    ~no_new_stack ~has_second_partition ~num_txs_per_round ~rounds ~no_masks
    ~max_depth ~tracing num_txs_final =
  O1trace.thread "mina"
  @@ fun () ->
  let%bind keypair = read_privkey privkey_path in
  let constraint_constants =
    Genesis_constants_compiled.Constraint_constants.t
  in
  let init_ledger =
    Ledger.create ~directory_name:ledger_path
      ~depth:constraint_constants.ledger_depth ()
  in
  let prev_protocol_state =
    let%map.Option prev_block_path = prev_block_path in
    let prev_block_data = In_channel.read_all prev_block_path in
    let prev_block =
      Binable.of_string (module Mina_block.Stable.Latest) prev_block_data
    in
    Mina_block.header prev_block |> Mina_block.Header.protocol_state
  in
  let genesis_constants = Genesis_constants_compiled.t in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants
      ~protocol_constants:genesis_constants.protocol
  in
  let prev_protocol_state =
    match prev_protocol_state with
    | None ->
        generate_protocol_state_stub ~consensus_constants ~constraint_constants
          init_ledger
    | Some p ->
        p
  in
  let apply =
    apply_txs ~genesis_constants ~constraint_constants ~first_partition_slots
      ~no_new_stack ~has_second_partition ~prev_protocol_state ~keypair
  in
  let mask_handler ledger =
    if no_masks then Fn.const ledger
    else
      Fn.compose (Ledger.register_mask ledger)
      @@ Ledger.Mask.create ~depth:constraint_constants.ledger_depth
  in
  let drop_old_ledger ledger =
    if not no_masks then (
      Ledger.commit ledger ;
      Ledger.remove_and_reparent_exn ledger ledger )
  in
  let stop_tracing =
    if tracing then (fun x -> Mina_tracing.stop () ; x) else ident
  in
  let init_root = Ledger.merkle_root init_ledger in
  printf !"Init root %s\n%!" (Ledger_hash.to_base58_check init_root) ;
  Deferred.List.fold (List.init rounds ~f:ident) ~init:(init_ledger, [])
    ~f:(fun (ledger, ledgers) i ->
      let%bind () =
        if tracing && i = 1 then Mina_tracing.start "." else Deferred.unit
      in
      List.hd (List.drop ledgers (max_depth - 1))
      |> Option.iter ~f:drop_old_ledger ;
      apply ~num_txs:num_txs_per_round ~i ledger
      >>| mask_handler ledger
      >>| Fn.flip Tuple2.create (ledger :: ledgers) )
  >>| fst
  >>= apply ~num_txs:num_txs_final ~i:rounds
  >>| stop_tracing
