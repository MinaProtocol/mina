open Core
open Async
open Signature_lib
open Mina_base
open Mina_state

(* Helpers for extend_blockchain, copied from prover.ml *)
let ledger_proof_opt next_state = function
  | Some t ->
      Ledger_proof.(statement_with_sok t, underlying_proof t)
  | None ->
      ( { (Blockchain_state.ledger_proof_statement
             (Protocol_state.blockchain_state next_state) )
          with
          sok_digest = Sok_message.Digest.default
        }
      , Lazy.force Proof.transaction_dummy )

let extend_blockchain ~proof_level
    (module B : Blockchain_snark.Blockchain_snark_state.S) ~constraint_constants
    (chain : Blockchain_snark.Blockchain.t)
    (next_state : Protocol_state.Value.t) (block : Snark_transition.value)
    (t : Ledger_proof.t option) state_for_handler pending_coinbase =
  (* Matches the daemon prover's behaviour at each proof level.
     At Check/No_check the daemon substitutes deterministic dummy proofs,
     so we must do the same to keep state hashes in sync. *)
  match (proof_level : Genesis_constants.Proof_level.t) with
  | Full ->
      Deferred.Or_error.try_with ~here:[%here] (fun () ->
          let txn_snark_statement, txn_snark_proof =
            ledger_proof_opt next_state t
          in
          let%map (), (), proof =
            B.step
              ~handler:
                (Consensus.Data.Prover_state.handler ~constraint_constants
                   state_for_handler ~pending_coinbase )
              { transition = block
              ; prev_state = Blockchain_snark.Blockchain.state chain
              ; prev_state_proof = Blockchain_snark.Blockchain.proof chain
              ; txn_snark = txn_snark_statement
              ; txn_snark_proof
              }
              next_state
          in
          Blockchain_snark.Blockchain.create ~state:next_state ~proof )
  | Check ->
      let txn_snark_statement, _txn_snark_proof =
        ledger_proof_opt next_state t
      in
      Blockchain_snark.Blockchain_snark_state.check ~proof_level
        ~constraint_constants
        { transition = block
        ; prev_state = Blockchain_snark.Blockchain.state chain
        ; prev_state_proof = Lazy.force Proof.blockchain_dummy
        ; txn_snark = txn_snark_statement
        ; txn_snark_proof = Lazy.force Proof.transaction_dummy
        }
        ~handler:
          (Consensus.Data.Prover_state.handler ~constraint_constants
             state_for_handler ~pending_coinbase )
        next_state
      |> Or_error.map ~f:(fun () ->
             Blockchain_snark.Blockchain.create ~state:next_state
               ~proof:(Lazy.force Proof.blockchain_dummy) )
      |> Deferred.return
  | No_check ->
      Deferred.return
        (Ok
           (Blockchain_snark.Blockchain.create
              ~proof:(Lazy.force Proof.blockchain_dummy)
              ~state:next_state ) )

module type Keys_S = sig
  module T : Transaction_snark.S

  module B : Blockchain_snark.Blockchain_snark_state.S
end

(* Copied from prover.ml, Worker_state.create *)
module Keys (Params : sig
  val signature_kind : Mina_signature_kind.t

  val constraint_constants : Genesis_constants.Constraint_constants.t

  val proof_level : Genesis_constants.Proof_level.t
end) : Keys_S = struct
  module T = Transaction_snark.Make (struct
    include Params
  end)

  module B = Blockchain_snark.Blockchain_snark_state.Make (struct
    let tag = T.tag

    include Params
  end)
end

let generate_next_state ~constraint_constants ~previous_protocol_state
    ~staged_ledger ~transactions ~get_completed_work ~logger
    ~(block_data : Consensus.Data.Block_data.t) ~winner_pk ~scheduled_time
    ~zkapp_cmd_limit_hardcap ~signature_kind =
  let open Deferred.Or_error.Let_syntax in
  let previous_protocol_state_body_hash =
    Protocol_state.body previous_protocol_state |> Protocol_state.Body.hash
  in
  let previous_protocol_state_hash =
    (Protocol_state.hashes_with_body
       ~body_hash:previous_protocol_state_body_hash previous_protocol_state )
      .state_hash
  in
  let previous_state_view =
    Protocol_state.body previous_protocol_state
    |> Mina_state.Protocol_state.Body.view
  in
  let global_slot =
    Consensus.Data.Block_data.global_slot_since_genesis block_data
  in
  let supercharge_coinbase =
    let epoch_ledger = Consensus.Data.Block_data.epoch_ledger block_data in
    Staged_ledger.can_apply_supercharged_coinbase_exn ~winner:winner_pk
      ~epoch_ledger ~global_slot
  in
  let coinbase_receiver =
    Consensus.Data.Block_data.coinbase_receiver block_data
  in
  let%bind diff, invalid_commands =
    Staged_ledger.create_diff ~constraint_constants ~global_slot staged_ledger
      ~coinbase_receiver ~logger ~current_state_view:previous_state_view
      ~transactions_by_fee:transactions ~get_completed_work
      ~log_block_creation:false ~supercharge_coinbase ~zkapp_cmd_limit:None
    |> Result.map_error ~f:(fun err ->
           Staged_ledger.Staged_ledger_error.Pre_diff err )
    |> Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
    |> Deferred.return
  in
  let%bind ( `Ledger_proof ledger_proof_opt
           , `Staged_ledger transitioned_staged_ledger
           , `Accounts_created accounts_created
           , `Pending_coinbase_update (is_new_stack, pending_coinbase_update) )
      =
    Staged_ledger.apply_diff_unchecked staged_ledger ~constraint_constants
      ~global_slot diff ~logger ~current_state_view:previous_state_view
      ~state_and_body_hash:
        (previous_protocol_state_hash, previous_protocol_state_body_hash)
      ~coinbase_receiver ~supercharge_coinbase ~zkapp_cmd_limit_hardcap
      ~signature_kind
    |> Deferred.Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
  in
  let staged_ledger_hash = Staged_ledger.hash transitioned_staged_ledger in
  let just_emitted_a_proof = Option.is_some ledger_proof_opt in
  let diff_unwrapped =
    Staged_ledger_diff.read_all_proofs_from_disk
    @@ Staged_ledger_diff.forget diff
  in
  let previous_ledger_hash =
    previous_protocol_state |> Protocol_state.blockchain_state
    |> Blockchain_state.snarked_ledger_hash
  in
  let ledger_proof_statement =
    match ledger_proof_opt with
    | Some proof ->
        Ledger_proof.Cached.statement proof
    | None ->
        previous_protocol_state |> Protocol_state.blockchain_state
        |> Blockchain_state.ledger_proof_statement
  in
  let genesis_ledger_hash =
    previous_protocol_state |> Protocol_state.blockchain_state
    |> Blockchain_state.genesis_ledger_hash
  in
  let supply_increase =
    Option.value_map ledger_proof_opt
      ~f:(fun proof -> (Ledger_proof.Cached.statement proof).supply_increase)
      ~default:Currency.Amount.Signed.zero
  in
  let body_reference =
    Staged_ledger_diff.Body.compute_reference
      ~tag:Mina_net2.Bitswap_tag.(to_enum Body)
      (Mina_block.Body.Stable.Latest.create diff_unwrapped)
  in
  let blockchain_state =
    Blockchain_state.create_value ~timestamp:scheduled_time ~genesis_ledger_hash
      ~staged_ledger_hash ~body_reference ~ledger_proof_statement
  in
  (* This current_time is used in the [generate_transition] method for the sole
     purpose of logging if the block was created after the slot was over. The
     stepper is not expected to run at the exact wall clock time implied by the
     genesis timestamp and slot, so this warning is useless for us. By using the
     scheduled time, we pretend we created the block instantly and so suppress
     this warning. *)
  let current_time =
    scheduled_time |> Block_time.to_span_since_epoch |> Block_time.Span.to_ms
  in
  let protocol_state, consensus_transition_data =
    Consensus_state_hooks.generate_transition ~previous_protocol_state
      ~blockchain_state ~current_time ~block_data ~supercharge_coinbase
      ~snarked_ledger_hash:previous_ledger_hash ~genesis_ledger_hash
      ~supply_increase ~logger ~constraint_constants
  in
  let snark_transition =
    Snark_transition.create_value
      ~blockchain_state:(Protocol_state.blockchain_state protocol_state)
      ~consensus_transition:consensus_transition_data ~pending_coinbase_update
      ()
  in
  let internal_transition =
    Mina_block.Internal_transition.create ~snark_transition
      ~prover_state:(Consensus.Data.Block_data.prover_state block_data)
      ~staged_ledger_diff:(Staged_ledger_diff.forget diff)
      ~ledger_proof:
        (Option.map ledger_proof_opt ~f:Ledger_proof.Cached.read_proof_from_disk)
  in
  let pending_coinbase_witness =
    { Pending_coinbase_witness.pending_coinbases =
        Staged_ledger.pending_coinbase_collection staged_ledger
    ; is_new_stack
    }
  in
  Deferred.Or_error.return
    ( protocol_state
    , internal_transition
    , pending_coinbase_witness
    , transitioned_staged_ledger
    , accounts_created
    , just_emitted_a_proof
    , invalid_commands )

let build_breadcrumb ~transactions ~context ~precomputed_values
    ~snark_work_provider ~protocol_states ?snark_work_count ?scheduled_time
    (module Keys : Keys_S) (slot_won, ledger_snapshot)
    (previous : Frontier_base.Breadcrumb.t) =
  let module V = Mina_block.Validation in
  let (module Context : V.CONTEXT) = context in
  let open Context in
  let open Deferred.Or_error.Let_syntax in
  let signature_kind = precomputed_values.Precomputed_values.signature_kind in
  let block_data =
    Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
      ~coinbase_receiver:`Producer
  in
  let slot_start_time =
    Consensus.Data.Consensus_time.(
      start_time ~constants:consensus_constants
        (of_global_slot ~constants:consensus_constants slot_won.global_slot))
  in
  let scheduled_time =
    match scheduled_time with Some t -> t | None -> slot_start_time
  in
  let previous_protocol_state =
    Frontier_base.Breadcrumb.protocol_state previous
  in
  let previous_proof =
    Frontier_base.Breadcrumb.block previous
    |> Mina_block.header |> Mina_block.Header.protocol_state_proof
  in
  let winner_pk = fst slot_won.delegator in
  let previous_staged_ledger =
    Frontier_base.Breadcrumb.staged_ledger previous
  in
  let prover = Public_key.compress slot_won.producer.public_key in
  let get_state hash =
    State_hash.Map.find protocol_states hash
    |> Result.of_option ~error:(Error.of_string "state not found")
  in
  let%bind work_specs =
    Staged_ledger.work_pairs_for_new_diff previous_staged_ledger ~get_state
    |> Deferred.return
  in
  let%bind work_specs =
    match snark_work_count with
    | Some n ->
        (* If a particular number of snark works are requested, match daemon
           block producer behaviour by taking from the head of the work
           required. This option exists because the daemon fetches the completed
           work for the work_pairs_for_new_diff in order, and stops once it
           finds a work spec that doesn't have work completed for it (or it's
           fetched them all). It can then further discard work depending on fee
           equation balancing. If the daemon ever did something different, we'd
           have to pass in the actual work IDs included in a block to guarantee
           that we replay the exact block the daemon generated. *)
        let taken, remaining =
          List.fold work_specs ~init:([], n) ~f:(fun (acc, remaining) spec ->
              if remaining <= 0 then (acc, remaining)
              else (spec :: acc, remaining - One_or_two.length spec) )
        in
        let taken = List.rev taken in
        let taken_count = List.sum (module Int) taken ~f:One_or_two.length in
        if remaining <> 0 then
          Deferred.Or_error.errorf
            "snark_work_count mismatch: requested %d items but took %d from %d \
             available specs"
            n taken_count (List.length work_specs)
        else (
          [%log info]
            "Selected $num_specs work specs ($num_items items) matching \
             snark_work_count"
            ~metadata:
              [ ("num_specs", `Int (List.length taken))
              ; ("num_items", `Int taken_count)
              ] ;
          Deferred.Or_error.return taken )
    | None ->
        Deferred.Or_error.return work_specs
  in
  let%bind get_completed_work =
    Snark_work.compute snark_work_provider ~fee:Currency.Fee.zero
      ~prover_key:prover work_specs
  in
  (* TODO: The returned transition_staged_ledger here contains a new mask. In
     the success path, the returned breadcrumb has ownership of it, but on
     failure it currently leaks. Add cleanup for it. Note: the block_producer
     does not have to deal with this because it immediately unregisters the
     mask and has the real frontier reconstruct it. *)
  let%bind ( protocol_state
           , internal_transition
           , pending_coinbase_witness
           , transitioned_staged_ledger
           , accounts_created
           , just_emitted_a_proof
           , invalid_commands ) =
    generate_next_state ~constraint_constants ~scheduled_time ~block_data
      ~previous_protocol_state ~staged_ledger:previous_staged_ledger
      ~transactions ~get_completed_work ~logger ~winner_pk
      ~zkapp_cmd_limit_hardcap:
        precomputed_values.genesis_constants.zkapp_cmd_limit_hardcap
      ~signature_kind
  in
  [%log info]
    "Generated protocol state and internal transition with $num_commands \
     commands"
    ~metadata:
      [ ( "num_commands"
        , `Int
            ( Mina_block.Internal_transition.staged_ledger_diff
                internal_transition
            |> Staged_ledger_diff.commands |> List.length ) )
      ] ;
  let proof_level = precomputed_values.Precomputed_values.proof_level in
  let%bind protocol_state_proof =
    extend_blockchain ~proof_level
      (module Keys.B)
      ~constraint_constants
      (Blockchain_snark.Blockchain.create ~proof:previous_proof
         ~state:previous_protocol_state )
      protocol_state
      (Mina_block.Internal_transition.snark_transition internal_transition)
      (Mina_block.Internal_transition.ledger_proof internal_transition)
      (Mina_block.Internal_transition.prover_state internal_transition)
      pending_coinbase_witness
    >>|? Blockchain_snark.Blockchain.proof
  in
  let previous_state_hash = Frontier_base.Breadcrumb.state_hash previous in
  let delta_block_chain_proof = (previous_state_hash, []) in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof
      ~delta_block_chain_proof ()
  in
  let body =
    Mina_block.Body.create
    @@ Mina_block.Internal_transition.staged_ledger_diff internal_transition
  in
  let%bind transition =
    let open Result.Let_syntax in
    V.wrap_header
      { With_hash.hash = Protocol_state.hashes protocol_state; data = header }
    |> V.skip_delta_block_chain_validation
         `This_block_was_not_received_via_gossip
    |> V.skip_time_received_validation `This_block_was_not_received_via_gossip
    |> Fn.flip V.with_body body
    |> V.skip_protocol_versions_validation
         `This_block_has_valid_protocol_versions
    |> V.validate_genesis_protocol_state_block
         ~genesis_state_hash:
           (Protocol_state.genesis_state_hash
              ~state_hash:(Some previous_state_hash) previous_protocol_state )
    >>| V.skip_proof_validation `This_block_was_generated_internally
    >>= V.validate_frontier_dependencies ~to_header:Mina_block.header ~context
          ~root_consensus_state:
            (Frontier_base.Breadcrumb.consensus_state_with_hashes previous)
          ~is_block_in_frontier:(State_hash.equal previous_state_hash)
    >>| V.skip_staged_ledger_diff_validation
          `This_block_has_a_trusted_staged_ledger
    |> Result.map_error
         ~f:(const (Error.of_string "failed to validate just created block"))
    |> Deferred.return
  in
  [%log info] "Building breadcrumb" ;
  (* This transition receipt time mirrors what the block producer does; the
     producer says that the block was received now because it was, in a sense.
     TODO: we're pretending this block was produced at its scheduled_time, which
     is very much not [Time.now ()] in general. We could pretend it was received
     at scheduled_time too, or in the middle of the slot. It should be
     deterministic regardless. (Caller could pass in a desired delta from
     scheduled time to receipt time, even). *)
  let transition_receipt_time = Some (Time.now ()) in
  Deferred.Or_error.return
    ( Frontier_base.Breadcrumb.create
        ~validated_transition:(Mina_block.Validated.lift transition)
        ~staged_ledger:transitioned_staged_ledger ~just_emitted_a_proof
        ~transition_receipt_time ~accounts_created
    , scheduled_time
    , invalid_commands )
