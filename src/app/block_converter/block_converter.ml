open Core
open Async
open Mina_base
open Mina_numbers
open Mina_state
open Archive_lib
open Signature_lib
open Currency

let transaction_status_of_extensional ~status ~failure_reason :
    Transaction_status.t =
  match status with
  | "applied" ->
      Applied
  | "failed" ->
      Failed
        (Transaction_status.Failure.Collection.of_single_failure
           (Option.value_exn failure_reason) )
  | _ ->
      failwithf "invalid transaction status \"%s\"" status ()

let signed_command_of_extensional_v1 (cmd : Extensional.User_command.Stable.V1.t)
    : User_command.t With_status.t =
  let ({ sequence_no = _
       ; typ = command_type
       ; fee_payer
       ; source = _
       ; receiver
       ; nonce
       ; amount
       ; fee
       ; valid_until
       ; memo
       ; hash = _
       ; status
       ; failure_reason
       ; fee_token = _
       ; token = _
       ; source_balance = _
       ; fee_payer_account_creation_fee_paid = _
       ; fee_payer_balance = _
       ; receiver_account_creation_fee_paid = _
       ; receiver_balance = _
       ; created_token = _
       }
        : Extensional.User_command.Stable.V1.t ) =
    cmd
  in
  let signed_command : Signed_command.t =
    let payload_body =
      match command_type with
      | "payment" ->
          Signed_command_payload.Body.Payment
            { receiver_pk = receiver; amount = Option.value_exn amount }
      | "delegation" ->
          Signed_command_payload.Body.Stake_delegation
            (Set_delegate { new_delegate = receiver })
      | _ ->
          failwithf "invalid signed command type \"%s\"" command_type ()
    in
    let payload : Signed_command_payload.t =
      { common =
          { fee
          ; fee_payer_pk = fee_payer
          ; nonce
          ; valid_until = Option.value_exn valid_until
          ; memo
          }
      ; body = payload_body
      }
    in
    { payload
    ; signer = Public_key.decompress_exn fee_payer
    ; signature = Signature.dummy
    }
  in
  { data = User_command.Signed_command signed_command
  ; status =
      transaction_status_of_extensional ~status
        ~failure_reason:
          (Option.map ~f:Transaction_status.Failure.Stable.V1.to_latest
             failure_reason )
  }

let fake_staged_ledger_diff_of_extensional_v1
    ~(internal_cmds : Extensional.Internal_command.Stable.V1.t list)
    ~(user_cmds : Extensional.User_command.Stable.V1.t list) :
    Staged_ledger_diff.t =
  (* ~(zkapp_cmds : Extensional.Zkapp_command.t list) *)

  (* currently unsupported: zkapp commands *)
  (* assert (List.is_empty zkapp_cmds) ; *)
  let completed_works = [] (* TODO *) in
  let internal_command_statuses =
    List.map internal_cmds ~f:(Fn.const Transaction_status.Applied)
    (* TODO: is this correct? *)
    (* List.map internal_cmds ~f:(fun {status; failure_reason; _} -> transaction_status_of_extensional ~status ~failure_reason) *)
  in
  (*
  let completed_works, internal_command_statuses =
    List.map internal_cmds ~f:(fun cmd ->
      match cmd.command_type with
      | "coinbase" ->
      | "fee_transfer" ->
      | _ -> failwithf "invalid internal command type \"%s\"" command_type ())
  in
  *)
  let commands =
    user_cmds
    |> List.sort ~compare:(fun a b -> Int.compare a.sequence_no b.sequence_no)
    |> List.map ~f:signed_command_of_extensional_v1
  in
  let coinbase =
    Staged_ledger_diff.At_most_two.Zero
    (* TODO: derive from internal cmds *)
  in
  { diff =
      ({ completed_works; commands; coinbase; internal_command_statuses }, None)
  }

let fake_precomputed_of_extensional_v1 ~genesis_state_hash ~genesis_ledger_hash
    (e : Extensional.Block.Stable.V1.t) : Mina_block.Precomputed.t =
  let ({ state_hash = _
       ; parent_hash = previous_state_hash
       ; creator = block_creator
       ; block_winner = block_stake_winner
       ; snarked_ledger_hash
       ; staking_epoch_seed
       ; staking_epoch_ledger_hash
       ; next_epoch_seed
       ; next_epoch_ledger_hash
       ; ledger_hash
       ; height = blockchain_length
       ; global_slot_since_hard_fork
       ; global_slot_since_genesis
       ; timestamp
       ; user_cmds
       ; internal_cmds
       ; chain_status = _
       }
        : Extensional.Block.Stable.V1.t ) =
    e
  in
  (* COMPILED VALUES *)
  let constraint_constants = Genesis_constants.Constraint_constants.compiled in
  let protocol_constants = Genesis_constants.compiled.protocol in
  let consensus_constants =
    Consensus.Constants.create ~constraint_constants ~protocol_constants
  in
  let ledger_depth = constraint_constants.ledger_depth in
  (* DERIVED VALUES *)
  (* let curr_global_slot_since_hard_fork : Mina_wire_types.Consensus_global_slot.V1.t = { slot_number = global_slot_since_hard_fork; slots_per_epoch } in *)
  let curr_global_slot_since_hard_fork =
    Consensus.Data.Consensus_time.of_global_slot ~constants:consensus_constants
      global_slot_since_hard_fork
  in
  let coinbase_receiver =
    List.find_map_exn internal_cmds ~f:(fun cmd ->
        Option.some_if (String.equal cmd.typ "coinbase") cmd.receiver )
  in
  let delta_transition_chain_proof = (previous_state_hash, []) in
  (* DUMMY VALUES *)
  let supercharge_coinbase = true in
  let epoch_count = Length.zero in
  let min_window_density = Length.zero in
  let sub_window_densities =
    List.init constraint_constants.sub_windows_per_window
      ~f:(Fn.const Length.zero)
  in
  let last_vrf_output = "00000000000000000000000000000000" in
  let has_ancestor_in_same_checkpoint_window = false in
  let total_currency = Amount.zero in
  let staking_epoch_data : Epoch_data.Value.t =
    { ledger = { hash = staking_epoch_ledger_hash; total_currency }
    ; seed = staking_epoch_seed
    ; start_checkpoint = Ledger_hash.empty_hash
    ; lock_checkpoint = Ledger_hash.empty_hash
    ; epoch_length = Length.zero
    }
  in
  let next_epoch_data : Epoch_data.Value.t =
    { ledger = { hash = next_epoch_ledger_hash; total_currency }
    ; seed = next_epoch_seed
    ; start_checkpoint = Ledger_hash.empty_hash
    ; lock_checkpoint = Ledger_hash.empty_hash
    ; epoch_length = Length.zero
    }
  in
  let scheduled_time =
    Block_time.of_span_since_epoch (Block_time.Span.of_ms 0L)
  in
  let body_reference =
    Consensus.Body_reference.of_hex_exn "00000000000000000000000000000000"
  in
  let staged_ledger_hash =
    Staged_ledger_hash.of_aux_ledger_and_coinbase_hash
      Staged_ledger_hash.Aux_hash.dummy ledger_hash
      (Or_error.ok_exn @@ Pending_coinbase.create ~depth:ledger_depth ())
  in
  let protocol_state_proof = Proof.blockchain_dummy in
  let protocol_version =
    Protocol_version.create ~transaction:2 ~network:0 ~patch:0
  in
  let proposed_protocol_version = Some protocol_version in
  let accounts_accessed = [] in
  let accounts_created = [] in
  let tokens_used = [] in
  (* COMBINED VALUES *)
  let registers : Registers.Value.t =
    { first_pass_ledger = snarked_ledger_hash
    ; second_pass_ledger = snarked_ledger_hash
    ; pending_coinbase_stack = Pending_coinbase.Stack.empty
    ; local_state = Local_state.empty ()
    }
  in
  let ledger_proof_statement : Snarked_ledger_state.t =
    { source = registers
    ; target = registers
    ; connecting_ledger_left = Ledger_hash.empty_hash
    ; connecting_ledger_right = Ledger_hash.empty_hash
    ; supply_increase = Amount.Signed.zero
    ; fee_excess = Fee_excess.zero
    ; sok_digest = ()
    }
  in
  let staged_ledger_diff =
    fake_staged_ledger_diff_of_extensional_v1 ~internal_cmds ~user_cmds
  in
  let blockchain_state =
    Blockchain_state.create_value ~staged_ledger_hash ~genesis_ledger_hash
      ~timestamp ~body_reference ~ledger_proof_statement
  in
  let consensus_state =
    Consensus.Data.Consensus_state.create ~blockchain_length ~epoch_count
      ~min_window_density ~sub_window_densities ~last_vrf_output ~total_currency
      ~curr_global_slot_since_hard_fork ~global_slot_since_genesis
      ~staking_epoch_data ~next_epoch_data
      ~has_ancestor_in_same_checkpoint_window ~block_stake_winner ~block_creator
      ~coinbase_receiver ~supercharge_coinbase
  in
  let protocol_state =
    Protocol_state.create_value ~previous_state_hash ~genesis_state_hash
      ~blockchain_state ~consensus_state
      ~constants:(Protocol_constants_checked.value_of_t protocol_constants)
  in
  { scheduled_time
  ; protocol_state
  ; protocol_state_proof
  ; staged_ledger_diff
  ; delta_transition_chain_proof
  ; protocol_version
  ; proposed_protocol_version
  ; accounts_accessed
  ; accounts_created
  ; tokens_used
  }

let main ~genesis_state_hash ~genesis_ledger_hash ~input_files =
  let output_filename input_filename =
    match Filename.split_extension input_filename with
    | base, Some ".json" ->
        base ^ ".precomputed.json"
    | _ ->
        failwithf
          "invalid input filename \"%s\" (expected file to end in \".json\")"
          input_filename ()
  in
  Deferred.List.iter input_files ~f:(fun input_file ->
      let%bind input =
        Reader.file_contents input_file >>| Yojson.Safe.from_string
      in
      let extensional_block =
        let versioned_input = `Assoc [ ("version", `Int 1); ("data", input) ] in
        Result.ok_or_failwith
          ([%of_yojson: Extensional.Block.Stable.V1.t] versioned_input)
      in
      let precomputed_block =
        fake_precomputed_of_extensional_v1 ~genesis_state_hash
          ~genesis_ledger_hash extensional_block
      in
      let output =
        Yojson.Safe.to_string
          ([%to_yojson: Mina_block.Precomputed.t] precomputed_block)
      in
      Writer.with_file (output_filename input_file) ~f:(fun w ->
          Writer.write_line w output ; Deferred.unit ) )

let (_ : never_returns) =
  (* TODO: real CLI *)
  let genesis_state_hash = State_hash.dummy in
  let genesis_ledger_hash = Ledger_hash.empty_hash in
  let args = Sys.get_argv () in
  let input_files =
    Array.to_list (Array.slice args 1 (Array.length args - 1))
  in
  Async.Scheduler.go_main
    ~main:(fun () ->
      don't_wait_for
        (main ~genesis_state_hash ~genesis_ledger_hash ~input_files) )
    ()
