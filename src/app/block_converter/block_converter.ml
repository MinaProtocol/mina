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

let signed_command_of_extensional (cmd : Extensional.User_command.t) :
    User_command.t With_status.t =
  let ({ sequence_no = _
       ; command_type
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
       }
        : Extensional.User_command.t ) =
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
  ; status = transaction_status_of_extensional ~status ~failure_reason
  }

let create_fake_staged_ledger_diff ~internal_cmds:_
    ~(user_cmds : Extensional.User_command.t list) ~zkapp_cmds :
    Staged_ledger_diff.t =
  (* currently unsupported: zkapp commands *)
  assert (List.is_empty zkapp_cmds) ;
  let completed_works = [] (* TODO: derive from internal cmds *) in
  let internal_command_statuses = [] (* TODO: derive from internal cmds *) in
  let commands =
    user_cmds
    |> List.sort ~compare:(fun a b -> Int.compare a.sequence_no b.sequence_no)
    |> List.map ~f:signed_command_of_extensional
  in
  let coinbase =
    Staged_ledger_diff.At_most_two.Zero
    (* TODO: derive from internal cmds *)
  in
  { diff =
      ({ completed_works; commands; coinbase; internal_command_statuses }, None)
  }

let extensional_to_fake_precomputed ~genesis_state_hash ~genesis_ledger_hash
    (e : Extensional.Block.t) : Mina_block.Precomputed.t =
  let ({ state_hash = _
       ; parent_hash = previous_state_hash
       ; creator = block_creator
       ; block_winner = block_stake_winner
       ; last_vrf_output
       ; snarked_ledger_hash
       ; staking_epoch_data
       ; next_epoch_data
       ; min_window_density
       ; total_currency
       ; sub_window_densities
       ; ledger_hash
       ; height = blockchain_length
       ; global_slot_since_hard_fork
       ; global_slot_since_genesis
       ; timestamp
       ; user_cmds
       ; internal_cmds
       ; zkapp_cmds
       ; protocol_version
       ; proposed_protocol_version
       ; chain_status = _
       ; accounts_accessed
       ; accounts_created
       ; tokens_used
       }
        : Extensional.Block.t ) =
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
        Option.some_if (String.equal cmd.command_type "Coinbase") cmd.receiver )
  in
  let delta_transition_chain_proof = (previous_state_hash, []) in
  (* DUMMY VALUES *)
  let supercharge_coinbase = true in
  let epoch_count = Length.zero in
  let has_ancestor_in_same_checkpoint_window = false in
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
    create_fake_staged_ledger_diff ~internal_cmds ~user_cmds ~zkapp_cmds
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

let main ~genesis_state_hash ~genesis_ledger_hash ~input_file =
  let%map input = Reader.file_contents input_file >>| Yojson.Safe.from_string in
  let extensional_blocks =
    Result.ok_or_failwith ([%of_yojson: Extensional.Block.t list] input)
  in
  let precomputed_blocks =
    List.map extensional_blocks
      ~f:
        (extensional_to_fake_precomputed ~genesis_state_hash
           ~genesis_ledger_hash )
  in
  let output =
    Yojson.Safe.to_string
      ([%to_yojson: Mina_block.Precomputed.t list] precomputed_blocks)
  in
  Writer.write_line (Lazy.force Writer.stdout) output

let (_ : never_returns) =
  (* TODO: CLI *)
  let genesis_state_hash = State_hash.dummy in
  let genesis_ledger_hash = Ledger_hash.empty_hash in
  Async.Scheduler.go_main
    ~main:(fun () ->
      don't_wait_for
        (main ~genesis_state_hash ~genesis_ledger_hash
           ~input_file:"extensional_blocks.json" ) )
    ()
