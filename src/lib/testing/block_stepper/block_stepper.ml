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

let extend_blockchain (module B : Blockchain_snark.Blockchain_snark_state.S)
    ~constraint_constants (chain : Blockchain_snark.Blockchain.t)
    (next_state : Protocol_state.Value.t) (block : Snark_transition.value)
    (t : Ledger_proof.t option) state_for_handler pending_coinbase =
  (* Copied from prover.ml *)
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

let create_genesis_proof m ~constraint_constants
    (genesis_inputs : Genesis_proof.Inputs.t) =
  (* Copied from block_producer.ml *)
  let ( blockchain
      , protocol_state
      , snark_transition
      , ledger_proof_opt
      , prover_state
      , pending_coinbase ) =
    Prover.create_genesis_block_inputs genesis_inputs
  in
  extend_blockchain m ~constraint_constants blockchain protocol_state
    snark_transition ledger_proof_opt prover_state pending_coinbase

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

let create_genesis_breadcrumb ~logger ~precomputed_values () =
  let signature_kind = precomputed_values.Precomputed_values.signature_kind in
  let constraint_constants = precomputed_values.constraint_constants in
  let module Params = struct
    let signature_kind = signature_kind

    let constraint_constants = constraint_constants

    let proof_level = precomputed_values.proof_level
  end in
  let module Keys = Keys (Params) in
  [%log info] "Generating genesis proof" ;
  let%map real_proof =
    create_genesis_proof
      (module Keys.B)
      ~constraint_constants
      (Genesis_proof.to_inputs precomputed_values)
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
  in
  let genesis_state =
    Precomputed_values.genesis_state_with_hashes precomputed_values
  in
  let protocol_state = With_hash.data genesis_state in
  let header =
    Mina_block.Header.create ~protocol_state ~protocol_state_proof:real_proof
      ~delta_block_chain_proof:
        (Protocol_state.previous_state_hash protocol_state, [])
      ()
  in
  let body = Mina_block.Body.create Staged_ledger_diff.empty_diff in
  let block = Mina_block.create ~header ~body in
  let block_with_hash = With_hash.map genesis_state ~f:(Fn.const block) in
  let validation =
    ( (`Time_received, Mina_stdlib.Truth.True ())
    , (`Genesis_state, Mina_stdlib.Truth.True ())
    , (`Proof, Mina_stdlib.Truth.True ())
    , ( `Delta_block_chain
      , Mina_stdlib.Truth.True
          ( Mina_stdlib.Nonempty_list.singleton
          @@ Protocol_state.previous_state_hash protocol_state ) )
    , (`Frontier_dependencies, Mina_stdlib.Truth.True ())
    , (`Staged_ledger_diff, Mina_stdlib.Truth.True ())
    , (`Protocol_versions, Mina_stdlib.Truth.True ()) )
  in
  let validated = Mina_block.Validated.lift (block_with_hash, validation) in
  let genesis_ledger =
    Precomputed_values.genesis_ledger precomputed_values |> Lazy.force
  in
  let mask =
    Mina_ledger.Ledger.Mask.create ~depth:constraint_constants.ledger_depth ()
  in
  let ledger = Mina_ledger.Ledger.register_mask genesis_ledger mask in
  let staged_ledger = Staged_ledger.create_exn ~constraint_constants ~ledger in
  let accounts_created =
    Precomputed_values.accounts precomputed_values
    |> Lazy.force
    |> List.map ~f:Precomputed_values.id_of_account_record
  in
  [%log info] "Creating genesis breadcrumb" ;
  Frontier_base.Breadcrumb.create ~validated_transition:validated ~staged_ledger
    ~transition_receipt_time:(Some (Time.now ()))
    ~just_emitted_a_proof:false ~accounts_created

let get_epoch_data_at_slot ~context:(module Context : Consensus.Intf.CONTEXT)
    ~consensus_state ~local_state ~slot =
  let global_slot = Mina_numbers.Global_slot_since_hard_fork.of_int slot in
  let time =
    Consensus.Data.Consensus_time.(
      start_time ~constants:Context.consensus_constants
        (of_global_slot ~constants:Context.consensus_constants global_slot))
  in
  let now = Block_time.Span.to_ms (Block_time.to_span_since_epoch time) in
  Consensus.Hooks.get_epoch_data_for_vrf ~constants:Context.consensus_constants
    now consensus_state ~local_state ~logger:Context.logger

let find_next_winning_slot ~context:(module Context : Consensus.Intf.CONTEXT)
    ~keypair ~start_slot ~epoch_data_for_vrf ~ledger_snapshot =
  let public_key_compressed = Public_key.compress keypair.Keypair.public_key in
  let logger = Context.logger in
  let { Consensus.Data.Epoch_data_for_vrf.epoch_ledger
      ; epoch_seed
      ; epoch = _
      ; global_slot = epoch_start_hf
      ; global_slot_since_genesis = epoch_start
      ; delegatee_table
      } =
    epoch_data_for_vrf
  in
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let epoch_end_slot = ((start_slot / slots_per_epoch) + 1) * slots_per_epoch in
  Deferred.repeat_until_finished start_slot
  @@ fun current_slot ->
  if current_slot >= epoch_end_slot then return (`Finished None)
  else
    let global_slot =
      Mina_numbers.Global_slot_since_hard_fork.of_int current_slot
    in
    match%map
      Consensus.Data.Vrf.check
        ~context:(module Context)
        ~global_slot ~seed:epoch_seed
        ~get_delegators:(Public_key.Compressed.Table.find delegatee_table)
        ~producer_private_key:keypair.private_key
        ~producer_public_key:public_key_compressed
        ~total_stake:epoch_ledger.total_currency
      |> Interruptible.force
    with
    | Error _ ->
        [%log fatal] "VRF check failed" ;
        failwith "VRF check failed"
    | Ok None ->
        `Repeat (current_slot + 1)
    | Ok
        (Some
          (`Vrf_eval _vrf_eval, `Vrf_output vrf_result, `Delegator delegator) )
      ->
        [%log info] "Found winning slot at global slot %d" current_slot ;
        let slot_won =
          { Consensus.Data.Slot_won.delegator
          ; producer = keypair
          ; global_slot
          ; global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.add epoch_start
                ( Mina_numbers.Global_slot_since_hard_fork.diff global_slot
                    epoch_start_hf
                |> Option.value_exn ~message:"failed to diff global slots" )
          ; vrf_result
          }
        in
        `Finished (Some ((slot_won, ledger_snapshot), current_slot + 1))

let generate_next_state ~constraint_constants ~previous_protocol_state
    ~staged_ledger ~transactions ~get_completed_work ~logger
    ~(block_data : Consensus.Data.Block_data.t) ~winner_pk ~scheduled_time
    ~zkapp_cmd_limit_hardcap ~signature_kind =
  let open Deferred.Let_syntax in
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
  let diff =
    Staged_ledger.create_diff ~constraint_constants ~global_slot staged_ledger
      ~coinbase_receiver ~logger ~current_state_view:previous_state_view
      ~transactions_by_fee:transactions ~get_completed_work
      ~log_block_creation:false ~supercharge_coinbase ~zkapp_cmd_limit:None
    |> Result.map_error ~f:(fun err ->
           Staged_ledger.Staged_ledger_error.Pre_diff err )
    |> Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
    |> Or_error.ok_exn |> fst
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
    >>| Result.map_error ~f:Staged_ledger.Staged_ledger_error.to_error
    >>| Or_error.ok_exn
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
     purpose of logging if the block was created ater the slot was over. The
     stepper is not expected to run at the exact wall clock time implied by the
     genesis timestamp and slot, so this warning is useless or us. By using the
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
  return
    ( protocol_state
    , internal_transition
    , pending_coinbase_witness
    , transitioned_staged_ledger
    , accounts_created
    , just_emitted_a_proof )

let build_breadcrumb ~transactions ~context ~precomputed_values ~signature_kind
    ~proof_cache_db ~protocol_states (module Keys : Keys_S)
    (slot_won, ledger_snapshot) (previous : Frontier_base.Breadcrumb.t) =
  let module V = Mina_block.Validation in
  let (module Context : V.CONTEXT) = context in
  let open Context in
  let block_data =
    Consensus.Hooks.get_block_data ~slot_won ~ledger_snapshot
      ~coinbase_receiver:`Producer
  in
  let scheduled_time =
    Consensus.Data.Consensus_time.(
      start_time ~constants:consensus_constants
        (of_global_slot ~constants:consensus_constants slot_won.global_slot))
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
  let work_specs =
    Staged_ledger.work_pairs_for_new_diff previous_staged_ledger ~get_state
    |> Or_error.ok_exn
  in
  let%bind get_completed_work =
    Snark_work.compute
      ~proof_level:precomputed_values.Precomputed_values.proof_level
      ~proof_cache_db ~signature_kind ~logger ~fee:Currency.Fee.zero
      ~prover_key:prover
      (module Keys.T)
      work_specs
    >>| Or_error.ok_exn
  in
  let%bind ( protocol_state
           , internal_transition
           , pending_coinbase_witness
           , transitioned_staged_ledger
           , accounts_created
           , just_emitted_a_proof ) =
    generate_next_state ~constraint_constants ~scheduled_time ~block_data
      ~previous_protocol_state ~staged_ledger:previous_staged_ledger
      ~transactions ~get_completed_work ~logger ~winner_pk
      ~zkapp_cmd_limit_hardcap:128 ~signature_kind
  in
  [%log info]
    "Generated protocol state and internal transition with %d commands"
    ( Mina_block.Internal_transition.staged_ledger_diff internal_transition
    |> Staged_ledger_diff.commands |> List.length ) ;
  let%bind protocol_state_proof =
    extend_blockchain
      (module Keys.B)
      ~constraint_constants
      (Blockchain_snark.Blockchain.create ~proof:previous_proof
         ~state:previous_protocol_state )
      protocol_state
      (Mina_block.Internal_transition.snark_transition internal_transition)
      (Mina_block.Internal_transition.ledger_proof internal_transition)
      (Mina_block.Internal_transition.prover_state internal_transition)
      pending_coinbase_witness
    >>| Or_error.ok_exn >>| Blockchain_snark.Blockchain.proof
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
  let transition =
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
    |> Or_error.ok_exn
  in
  [%log info] "Building breadcrumb" ;
  return
    (Frontier_base.Breadcrumb.create
       ~validated_transition:(Mina_block.Validated.lift transition)
       ~staged_ledger:transitioned_staged_ledger ~just_emitted_a_proof
       ~transition_receipt_time:(Some (Time.now ()))
       ~accounts_created )

type t =
  { precomputed_values : Precomputed_values.t
  ; context : (module Consensus.Intf.CONTEXT)
  ; keys_module : (module Keys_S)
  ; current : Frontier_base.Breadcrumb.t
  ; logger : Logger.t
  ; keypair : Keypair.t
  ; next_search_slot : int
  ; proof_cache_db : Proof_cache_tag.cache_db
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; epoch_data :
      Consensus.Data.Epoch_data_for_vrf.t
      * Consensus.Data.Local_state.Snapshot.Ledger_snapshot.t
  }

type start_state =
  { breadcrumb : Frontier_base.Breadcrumb.t
  ; protocol_states : Protocol_state.value State_hash.Map.t
  ; keys_module : (module Keys_S)
  }

let start_state_of_genesis breadcrumb ~keys_module =
  let hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  { breadcrumb
  ; protocol_states = State_hash.Map.singleton hash protocol_state
  ; keys_module
  }

let start_state_of_breadcrumb breadcrumb ~protocol_states ~keys_module =
  { breadcrumb; protocol_states; keys_module }

let current_block t = t.current

let precomputed_values t = t.precomputed_values

let create ~precomputed_values ~keypair ~start ~logger ~state_dir () =
  let start_block = start.breadcrumb in
  let keys_module = start.keys_module in
  let context =
    let module Context = struct
      let logger = logger

      let constraint_constants =
        precomputed_values.Precomputed_values.constraint_constants

      let consensus_constants = precomputed_values.consensus_constants
    end in
    (module Context : Consensus.Intf.CONTEXT)
  in
  let (module Context : Consensus.Intf.CONTEXT) = context in
  let next_search_slot =
    Frontier_base.Breadcrumb.consensus_state start_block
    |> Consensus.Data.Consensus_state.curr_global_slot
    |> Mina_numbers.Global_slot_since_hard_fork.to_int |> ( + ) 1
  in
  let%bind proof_cache_db =
    Proof_cache_tag.create_db (Filename.concat state_dir "proof_cache") ~logger
    >>| Result.map_error ~f:(fun (`Initialization_error e) -> e)
    >>| Or_error.ok_exn
  in
  let consensus_local_state =
    Consensus.Data.Local_state.create
      ~context:(module Context)
      ~genesis_ledger:precomputed_values.Precomputed_values.genesis_ledger
      ~genesis_epoch_data:precomputed_values.genesis_epoch_data
      ~epoch_ledger_location:(Filename.concat state_dir "epoch_ledger")
      (Public_key.Compressed.Set.singleton
         (Public_key.compress keypair.Keypair.public_key) )
      ~genesis_state_hash:
        precomputed_values.protocol_state_with_hashes.hash.state_hash
      ~epoch_ledger_backing_type:Stable_db
  in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state start_block in
  let epoch_data =
    get_epoch_data_at_slot
      ~context:(module Context)
      ~consensus_state ~local_state:consensus_local_state ~slot:next_search_slot
  in
  return
    { precomputed_values
    ; context
    ; keys_module
    ; current = start_block
    ; logger
    ; keypair
    ; next_search_slot
    ; proof_cache_db
    ; protocol_states = start.protocol_states
    ; consensus_local_state
    ; epoch_data
    }

let step t ~transactions =
  let logger = t.logger in
  let (module Context : Consensus.Intf.CONTEXT) = t.context in
  let slots_per_epoch =
    Mina_numbers.Length.to_int Context.consensus_constants.slots_per_epoch
  in
  let max_search_slots = 2 * slots_per_epoch in
  let consensus_state = Frontier_base.Breadcrumb.consensus_state t.current in
  let rec find_slot ~epoch_data ~start_slot ~slots_searched =
    if slots_searched >= max_search_slots then
      failwith "Could not find winning slot within 2 epochs" ;
    let epoch_data_for_vrf, ledger_snapshot = epoch_data in
    let epoch_end_slot =
      ((start_slot / slots_per_epoch) + 1) * slots_per_epoch
    in
    match%bind
      find_next_winning_slot ~context:t.context ~keypair:t.keypair ~start_slot
        ~epoch_data_for_vrf ~ledger_snapshot
    with
    | Some (winner, next_slot) ->
        return (winner, next_slot, epoch_data)
    | None ->
        [%log info] "Epoch exhausted at slot %d, recomputing for next epoch"
          epoch_end_slot ;
        let new_epoch_data =
          get_epoch_data_at_slot ~context:t.context ~consensus_state
            ~local_state:t.consensus_local_state ~slot:epoch_end_slot
        in
        let slots_in_this_epoch = epoch_end_slot - start_slot in
        find_slot ~epoch_data:new_epoch_data ~start_slot:epoch_end_slot
          ~slots_searched:(slots_searched + slots_in_this_epoch)
  in
  [%log info] "Searching for next winning slot from slot %d" t.next_search_slot ;
  let%bind (slot_won, ledger_snapshot), next_search_slot, epoch_data =
    find_slot ~epoch_data:t.epoch_data ~start_slot:t.next_search_slot
      ~slots_searched:0
  in
  let signature_kind = t.precomputed_values.signature_kind in
  let%map breadcrumb =
    build_breadcrumb ~transactions ~context:t.context
      ~precomputed_values:t.precomputed_values ~signature_kind
      ~proof_cache_db:t.proof_cache_db ~protocol_states:t.protocol_states
      t.keys_module
      (slot_won, ledger_snapshot)
      t.current
  in
  let state_hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  let protocol_state = Frontier_base.Breadcrumb.protocol_state breadcrumb in
  let protocol_states =
    State_hash.Map.set t.protocol_states ~key:state_hash ~data:protocol_state
  in
  ( breadcrumb
  , { t with
      current = breadcrumb
    ; next_search_slot
    ; protocol_states
    ; epoch_data
    } )
