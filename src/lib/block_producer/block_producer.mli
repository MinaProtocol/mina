module Time = Block_time

type Structured_log_events.t += Block_produced

val block_produced_structured_events_id : Structured_log_events.id

val block_produced_structured_events_repr : Structured_log_events.repr

module Singleton_supervisor : sig
  type ('data, 'a) t

  val create :
       task:(unit Async.Ivar.t -> 'data -> ('a, unit) Interruptible.t)
    -> ('data, 'a) t

  val cancel : ('a, 'b) t -> unit

  val dispatch : ('data, 'a) t -> 'data -> ('a, unit) Interruptible.t
end

module Transition_frontier_validation : sig
  val validate_frontier_dependencies :
       ( [ `Time_received ] * (unit, 'a) Truth.t
       , [ `Genesis_state ] * (unit, 'b) Truth.t
       , [ `Proof ] * (unit, 'c) Truth.t
       , [ `Delta_transition_chain ]
         * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
       , [ `Frontier_dependencies ] * unit Truth.false_t
       , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
       , [ `Protocol_versions ] * (unit, 'f) Truth.t )
       Mina_transition__External_transition.Validation.with_transition
    -> consensus_constants:Consensus.Constants.t
    -> logger:Logger.t
    -> frontier:Transition_frontier.t
    -> ( ( [ `Time_received ] * (unit, 'a) Truth.t
         , [ `Genesis_state ] * (unit, 'b) Truth.t
         , [ `Proof ] * (unit, 'c) Truth.t
         , [ `Delta_transition_chain ]
           * (Mina_base.State_hash.t Non_empty_list.t, 'd) Truth.t
         , [ `Frontier_dependencies ] * unit Truth.true_t
         , [ `Staged_ledger_diff ] * (unit, 'e) Truth.t
         , [ `Protocol_versions ] * (unit, 'f) Truth.t )
         Mina_transition__External_transition.Validation.with_transition
       , [> `Already_in_frontier
         | `Not_selected_over_frontier_root
         | `Parent_missing_from_frontier ] )
       Core_kernel.Result.t
end

val time_to_ms : Block_time.t -> Core_kernel.Int64.t

val time_of_ms : Core_kernel.Int64.t -> Block_time.t

val lift_sync : (unit -> 'a) -> ('a, 'b) Interruptible.t

module Singleton_scheduler : sig
  type t

  val create : Block_time.Controller.t -> t

  val schedule : t -> Block_time.t -> f:(unit -> unit) -> unit
end

val generate_next_state :
     constraint_constants:Genesis_constants.Constraint_constants.t
  -> previous_protocol_state:
       ( Mina_base.State_hash.Stable.V1.t
       , Mina_state.Protocol_state.Body.Value.t )
       Mina_state.Protocol_state.Poly.t
  -> time_controller:Block_time.Controller.t
  -> staged_ledger:Staged_ledger.t
  -> transactions:Mina_base.User_command.Valid.t Core_kernel.Sequence.t
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option)
  -> logger:Logger.t
  -> block_data:Consensus.Data.Block_data.t
  -> winner_pk:Signature_lib.Public_key.Compressed.t
  -> scheduled_time:Block_time.t
  -> log_block_creation:bool
  -> block_reward_threshold:Currency.Amount.Stable.Latest.t option
  -> ( ( Mina_state.Protocol_state.Value.t
       * Mina_transition.Internal_transition.Stable.Latest.t
       * Mina_base.Pending_coinbase_witness.t )
       option
     , 'a )
     Interruptible.t

module Precomputed_block : sig
  type t = Mina_transition.External_transition.Precomputed_block.t =
    { scheduled_time : Block_time.t
    ; protocol_state : Mina_state.Protocol_state.value
    ; protocol_state_proof : Mina_base.Proof.t
    ; staged_ledger_diff : Staged_ledger_diff.t
    ; delta_transition_chain_proof :
        Mina_base.Frozen_ledger_hash.t * Mina_base.Frozen_ledger_hash.t list
    }

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val t_of_sexp : Sexplib0.Sexp.t -> t
end

val handle_block_production_errors :
     logger:Logger.t
  -> rejected_blocks_logger:Logger.t
  -> time_taken:Block_time.Span.t
  -> previous_protocol_state:Mina_state.Protocol_state.value
  -> protocol_state:Mina_state.Protocol_state.Value.t
  -> ( unit
     , [< `Already_in_frontier
       | `Fatal_error of exn
       | `Invalid_genesis_protocol_state
       | `Invalid_staged_ledger_diff of Base.Error.t * Staged_ledger_diff.t
       | `Invalid_staged_ledger_hash of Core.Error.t
       | `Not_selected_over_frontier_root
       | `Parent_missing_from_frontier
       | `Prover_error of
         Base.Error.t
         * ( Mina_base.Proof.t
           * Mina_transition.Internal_transition.t
           * Mina_base.Pending_coinbase_witness.t ) ] )
     Core._result
  -> unit Async_kernel__Deferred.t

val time :
     logger:Logger.t
  -> time_controller:Block_time.Controller.t
  -> string
  -> (unit -> ('a, 'b) Async_kernel__Deferred_result.t)
  -> ('a, 'b) Async_kernel__Deferred_result.t

val retry :
     ?max:Core_kernel__Int.t
  -> logger:Logger.t
  -> error_message:string
  -> (unit -> ('a, Core.Error.t) Core._result Async_kernel__Deferred.t)
  -> 'a Async_kernel__Deferred.t

module Vrf_evaluation_state : sig
  type status = At of Mina_numbers.Global_slot.t | Start | Completed

  type t =
    { queue : Consensus.Data.Slot_won.t Core.Queue.t
    ; mutable vrf_evaluator_status : status
    }

  val poll_vrf_evaluator :
       logger:Logger.t
    -> Vrf_evaluator.t
    -> Vrf_evaluator.Vrf_evaluation_result.t Async_kernel__Deferred.t

  val create : unit -> t

  val finished : t -> bool

  val evaluator_status : t -> status

  val update_status : t -> Vrf_evaluator.Evaluator_status.t -> unit

  val poll :
       vrf_evaluator:Vrf_evaluator.t
    -> logger:Logger.t
    -> t
    -> unit Async_kernel__Deferred.t

  val update_epoch_data :
       vrf_evaluator:Vrf_evaluator.t
    -> logger:Logger.t
    -> epoch_data_for_vrf:Consensus.Data.Epoch_data_for_vrf.t
    -> t
    -> unit Async_kernel__Deferred.t
end

val run :
     logger:Logger.t
  -> vrf_evaluator:Vrf_evaluator.t
  -> prover:Prover.t
  -> verifier:Verifier.t
  -> trust_system:Trust_system.t
  -> get_completed_work:
       (   Transaction_snark_work.Statement.t
        -> Transaction_snark_work.Checked.t option)
  -> transaction_resource_pool:Network_pool.Transaction_pool.Resource_pool.t
  -> time_controller:Block_time.Controller.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> coinbase_receiver:Consensus.Coinbase_receiver.t Core.ref
  -> frontier_reader:
       Transition_frontier.t option Pipe_lib.Broadcast_pipe.Reader.t
  -> transition_writer:
       ( Frontier_base__Breadcrumb.t
       , 'a
       , unit Async.Deferred.t )
       Pipe_lib.Strict_pipe.Writer.t
  -> set_next_producer_timing:
       (   [> `Check_again of Block_time.t
           | `Evaluating_vrf of Mina_numbers.Global_slot.t
           | `Produce of
             Core_kernel.Int64.t
             * Consensus.Data.Block_data.t
             * Signature_lib.Public_key.Compressed.t
           | `Produce_now of
             Consensus.Data.Block_data.t * Signature_lib.Public_key.Compressed.t
           ]
        -> Consensus.Data.Consensus_state.Value.t
        -> unit)
  -> log_block_creation:bool
  -> precomputed_values:Precomputed_values.t
  -> block_reward_threshold:Currency.Amount.Stable.Latest.t option
  -> block_produced_bvar:
       (Frontier_base__Breadcrumb.t, [> Core_kernel.write ]) Async.Bvar.t
  -> unit

val run_precomputed :
     logger:Logger.t
  -> verifier:Verifier.t
  -> trust_system:Trust_system.t
  -> time_controller:Block_time.Controller.t
  -> frontier_reader:
       Transition_frontier.t option Pipe_lib.Broadcast_pipe.Reader.t
  -> transition_writer:
       ( Frontier_base__Breadcrumb.t
       , 'a
       , unit Async.Deferred.t )
       Pipe_lib.Strict_pipe.Writer.t
  -> precomputed_blocks:Precomputed_block.t Base.Sequence.t
  -> precomputed_values:Precomputed_values.t
  -> unit Async_kernel__Deferred.t
