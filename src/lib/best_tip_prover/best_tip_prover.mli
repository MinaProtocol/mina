module type Inputs_intf = sig
  module Transition_frontier : sig
    module Breadcrumb = Frontier_base.Breadcrumb
    module Diff = Frontier_base.Diff
    module Extensions = Extensions
    module Persistent_root = Persistent_root
    module Persistent_frontier = Persistent_frontier
    module Root_data = Frontier_base.Root_data
    module Catchup_tree = Transition_frontier__.Catchup_tree
    module Full_catchup_tree = Transition_frontier__.Full_catchup_tree
    module Catchup_hash_tree = Transition_frontier__.Catchup_hash_tree

    type t

    val find_exn : t -> Mina_base.State_hash.t -> Frontier_base.Breadcrumb.t

    val max_length : t -> int

    val consensus_local_state : t -> Consensus.Data.Local_state.t

    val all_breadcrumbs : t -> Frontier_base.Breadcrumb.t list

    val root_length : t -> int

    val root : t -> Frontier_base.Breadcrumb.t

    val best_tip : t -> Frontier_base.Breadcrumb.t

    val best_tip_path : ?max_length:int -> t -> Frontier_base.Breadcrumb.t list

    val path_map :
         ?max_length:int
      -> t
      -> Frontier_base.Breadcrumb.t
      -> f:(Frontier_base.Breadcrumb.t -> 'a)
      -> 'a list

    val hash_path :
      t -> Frontier_base.Breadcrumb.t -> Mina_base.State_hash.t list

    val find : t -> Mina_base.State_hash.t -> Frontier_base.Breadcrumb.t option

    val find_protocol_state :
      t -> Mina_base.State_hash.t -> Mina_state.Protocol_state.value option

    val successor_hashes :
      t -> Mina_base.State_hash.t -> Mina_base.State_hash.t list

    val successor_hashes_rec :
      t -> Mina_base.State_hash.t -> Mina_base.State_hash.t list

    val successors :
      t -> Frontier_base.Breadcrumb.t -> Frontier_base.Breadcrumb.t list

    val successors_rec :
      t -> Frontier_base.Breadcrumb.t -> Frontier_base.Breadcrumb.t list

    val common_ancestor :
         t
      -> Frontier_base.Breadcrumb.t
      -> Frontier_base.Breadcrumb.t
      -> Mina_base.State_hash.t

    val iter : t -> f:(Frontier_base.Breadcrumb.t -> unit) -> unit

    val best_tip_path_length_exn : t -> int

    val visualize_to_string : t -> string

    val visualize : filename:string -> t -> unit

    val precomputed_values : t -> Precomputed_values.t

    val genesis_constants : t -> Genesis_constants.t

    type Structured_log_events.t += Added_breadcrumb_user_commands

    val added_breadcrumb_user_commands_structured_events_id :
      Structured_log_events.id

    val added_breadcrumb_user_commands_structured_events_repr :
      Structured_log_events.repr

    type Structured_log_events.t +=
      | Applying_diffs of { diffs : Yojson.Safe.t list }

    val applying_diffs_structured_events_id : Structured_log_events.id

    val applying_diffs_structured_events_repr : Structured_log_events.repr

    val max_catchup_chunk_length : int

    val catchup_tree : t -> Transition_frontier__.Catchup_tree.t

    val global_max_length : Genesis_constants.t -> int

    val load :
         ?retry_with_fresh_db:bool
      -> logger:Logger.t
      -> verifier:Verifier.t
      -> consensus_local_state:Consensus.Data.Local_state.t
      -> persistent_root:Persistent_root.t
      -> persistent_frontier:Persistent_frontier.t
      -> precomputed_values:Precomputed_values.t
      -> catchup_mode:[ `Normal | `Super ]
      -> unit
      -> ( t
         , [> `Bootstrap_required
           | `Failure of string
           | `Persistent_frontier_malformed
           | `Snarked_ledger_mismatch ] )
         Async_kernel.Deferred.Result.t

    val close : loc:string -> t -> unit Async_kernel.Deferred.t

    val closed : t -> unit Async_kernel.Deferred.t

    val add_breadcrumb_exn :
      t -> Frontier_base.Breadcrumb.t -> unit Async_kernel.Deferred.t

    val persistent_root : t -> Persistent_root.t

    val persistent_frontier : t -> Persistent_frontier.t

    val root_snarked_ledger : t -> Mina_base.Ledger.Db.t

    val extensions : t -> Extensions.t

    val genesis_state_hash : t -> Mina_base.State_hash.t

    val rejected_blocks :
      ( Mina_base.State_hash.t
      * Network_peer.Envelope.Sender.t
      * Block_time.t
      * [ `Invalid_delta_transition_chain_proof
        | `Invalid_genesis_protocol_state
        | `Invalid_proof
        | `Invalid_protocol_version
        | `Mismatched_protocol_version
        | `Too_early
        | `Too_late ] )
      Core.Queue.t

    val validated_blocks :
      (Mina_base.State_hash.t * Network_peer.Envelope.Sender.t * Block_time.t)
      Core.Queue.t

    module For_tests : sig
      val equal : t -> t -> bool

      val load_with_max_length :
           max_length:int
        -> ?retry_with_fresh_db:bool
        -> logger:Logger.t
        -> verifier:Verifier.t
        -> consensus_local_state:Consensus.Data.Local_state.t
        -> persistent_root:Persistent_root.t
        -> persistent_frontier:Persistent_frontier.t
        -> precomputed_values:Precomputed_values.t
        -> catchup_mode:[ `Normal | `Super ]
        -> unit
        -> ( t
           , [> `Bootstrap_required
             | `Failure of string
             | `Persistent_frontier_malformed
             | `Snarked_ledger_mismatch ] )
           Async_kernel.Deferred.Result.t

      val gen_genesis_breadcrumb :
           ?logger:Logger.t
        -> verifier:Verifier.t
        -> precomputed_values:Precomputed_values.t
        -> unit
        -> Frontier_base.Breadcrumb.t Core_kernel.Quickcheck.Generator.t

      val gen_persistence :
           ?logger:Logger.t
        -> verifier:Verifier.t
        -> precomputed_values:Precomputed_values.t
        -> unit
        -> (Persistent_root.t * Persistent_frontier.t)
           Core_kernel.Quickcheck.Generator.t

      val gen :
           ?logger:Logger.t
        -> verifier:Verifier.t
        -> ?trust_system:Trust_system.t
        -> ?consensus_local_state:Consensus.Data.Local_state.t
        -> precomputed_values:Precomputed_values.t
        -> ?root_ledger_and_accounts:
             Mina_base.Ledger.t
             * (Signature_lib.Private_key.t option * Mina_base.Account.t) list
        -> ?gen_root_breadcrumb:
             ( Frontier_base.Breadcrumb.t
             * Mina_state.Protocol_state.value
               Mina_base.State_hash.With_state_hashes.t
               list )
             Core_kernel.Quickcheck.Generator.t
        -> max_length:int
        -> size:int
        -> ?use_super_catchup:bool
        -> unit
        -> t Core_kernel.Quickcheck.Generator.t

      val gen_with_branch :
           ?logger:Logger.t
        -> verifier:Verifier.t
        -> ?trust_system:Trust_system.t
        -> ?consensus_local_state:Consensus.Data.Local_state.t
        -> precomputed_values:Precomputed_values.t
        -> ?root_ledger_and_accounts:
             Mina_base.Ledger.t
             * (Signature_lib.Private_key.t option * Mina_base.Account.t) list
        -> ?gen_root_breadcrumb:
             ( Frontier_base.Breadcrumb.t
             * Mina_state.Protocol_state.value
               Mina_base.State_hash.With_state_hashes.t
               list )
             Core_kernel.Quickcheck.Generator.t
        -> ?get_branch_root:(t -> Frontier_base.Breadcrumb.t)
        -> max_length:int
        -> frontier_size:int
        -> branch_size:int
        -> ?use_super_catchup:bool
        -> unit
        -> (t * Frontier_base.Breadcrumb.t list)
           Core_kernel.Quickcheck.Generator.t
    end
  end
end

module Make : functor (Inputs : Inputs_intf) -> sig
  val prove :
       logger:Logger.t
    -> Inputs.Transition_frontier.t
    -> ( Mina_transition.External_transition.t
         Mina_base.State_hash.With_state_hashes.t
       , Mina_base.State_body_hash.t list
         * Mina_transition.External_transition.t )
       Proof_carrying_data.t
       option

  val verify :
       verifier:Verifier.t
    -> genesis_constants:Genesis_constants.t
    -> precomputed_values:Precomputed_values.t
    -> ( Mina_transition.External_transition.t
       , Mina_base.State_body_hash.t list
         * Mina_transition.External_transition.t )
       Proof_carrying_data.t
    -> ( [ `Root of Mina_transition.External_transition.Initial_validated.t ]
       * [ `Best_tip of Mina_transition.External_transition.Initial_validated.t ]
       )
       Async_kernel.Deferred.Or_error.t
end

val prove :
     logger:Logger.t
  -> Transition_frontier.t
  -> ( Mina_transition.External_transition.t
       Mina_base.State_hash.With_state_hashes.t
     , Mina_base.State_body_hash.t list * Mina_transition.External_transition.t
     )
     Proof_carrying_data.t
     option

val verify :
     verifier:Verifier.t
  -> genesis_constants:Genesis_constants.t
  -> precomputed_values:Precomputed_values.t
  -> ( Mina_transition.External_transition.t
     , Mina_base.State_body_hash.t list * Mina_transition.External_transition.t
     )
     Proof_carrying_data.t
  -> ( [ `Root of Mina_transition.External_transition.Initial_validated.t ]
     * [ `Best_tip of Mina_transition.External_transition.Initial_validated.t ]
     )
     Async_kernel.Deferred.Or_error.t
