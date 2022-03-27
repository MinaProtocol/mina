val verify_transition :
     logger:Logger.t
  -> consensus_constants:Consensus.Constants.t
  -> trust_system:Trust_system.t
  -> frontier:Transition_frontier.t
  -> unprocessed_transition_cache:
       Transition_handler.Unprocessed_transition_cache.t
  -> ( [ `Time_received ] * unit Truth.false_t
     , [ `Genesis_state ] * unit Truth.false_t
     , [ `Proof ] * unit Truth.true_t
     , [ `Delta_transition_chain ]
       * Mina_base.State_hash.t Non_empty_list.t Truth.false_t
     , [ `Frontier_dependencies ] * unit Truth.false_t
     , [ `Staged_ledger_diff ] * unit Truth.false_t
     , [ `Protocol_versions ] * unit Truth.false_t )
     Mina_transition.External_transition.Validation.with_transition
     Network_peer.Envelope.Incoming.t
  -> ( [> `Building_path of
          ( Transition_handler.Unprocessed_transition_cache.source
          , Transition_handler.Unprocessed_transition_cache.target )
          Cache_lib.Cached.t
       | `In_frontier of Data_hash_lib.State_hash.Stable.V1.t ]
     , Core.Error.t )
     Core._result
     Async.Deferred.t

val fold_until :
     init:'accum
  -> f:
       (   'accum
        -> 'a
        -> ('accum, 'final) Core.Continue_or_stop.t Async.Deferred.Or_error.t)
  -> finish:('accum -> 'final Async.Deferred.Or_error.t)
  -> 'a list
  -> 'final Async.Deferred.Or_error.t

val find_map_ok :
     'a list
  -> f:('a -> ('b, 'c) Core._result Async.Deferred.t)
  -> ('b, 'c list) Core._result Async.Deferred.t

type download_state_hashes_error =
  [ `Failed_to_download_transition_chain_proof of Core.Error.t
  | `Invalid_transition_chain_proof of Core.Error.t
  | `No_common_ancestor of Core.Error.t
  | `Peer_moves_too_fast of Core.Error.t ]

val display_error :
     [< `Failed_to_download_transition_chain_proof of Core.Error.t
     | `Invalid_transition_chain_proof of Core.Error.t
     | `No_common_ancestor of Core.Error.t
     | `Peer_moves_too_fast of Core.Error.t ]
  -> string

val contains_no_common_ancestor : [> `No_common_ancestor of 'a ] list -> bool

val to_error :
     [< `Failed_to_download_transition_chain_proof of 'a
     | `Invalid_transition_chain_proof of 'a
     | `No_common_ancestor of 'a
     | `Peer_moves_too_fast of 'a ]
  -> 'a

val download_state_hashes :
     logger:Logger.t
  -> trust_system:Trust_system.t
  -> network:Mina_networking.t
  -> frontier:Transition_frontier.t
  -> peers:Network_peer.Peer.t list
  -> target_hash:Mina_base.State_hash.t
  -> job:Transition_frontier.Catchup_hash_tree.Catchup_job_id.Hash_set.elt
  -> hash_tree:Transition_frontier.Catchup_hash_tree.t
  -> blockchain_length_of_target_hash:Unsigned.UInt32.t
  -> ( Network_peer.Peer.t * Mina_base.State_hash.t list
     , [> `Failed_to_download_transition_chain_proof of Core_kernel__.Error.t
       | `Invalid_transition_chain_proof of Core.Error.t
       | `No_common_ancestor of Core.Error.t
       | `Peer_moves_too_fast of Core.Error.t ]
       list )
     Async_kernel__Deferred_result.t

val verify_against_hashes :
     ('a, Mina_base__State_hash.State_hashes.t) With_hash.t list
  -> Mina_base.State_hash.t list
  -> bool

val partition : int -> 'a list -> 'a list list

module Peers_pool : sig
  type t =
    { preferred : Network_peer.Peer.t Core.Queue.t
    ; normal : Network_peer.Peer.t Core.Queue.t
    ; busy : Network_peer.Peer.Hash_set.t
    }

  val create :
       busy:Network_peer.Peer.Hash_set.t
    -> preferred:Network_peer.Peer.t list
    -> Network_peer.Peer.t list
    -> t

  val dequeue :
    t -> [> `All_busy | `Available of Network_peer.Peer.Hash_set.elt | `Empty ]
end

val download_transitions :
     target_hash:Mina_base.State_hash.t
  -> logger:Logger.t
  -> trust_system:Trust_system.t
  -> network:Mina_networking.t
  -> preferred_peer:Network_peer.Peer.t
  -> hashes_of_missing_transitions:Mina_base.State_hash.t list
  -> ( Mina_transition.External_transition.t
     , Mina_base.State_hash.State_hashes.t )
     With_hash.t
     Network_peer.Envelope.Incoming.t
     list
     Async_kernel__Deferred_or_error.t

val verify_transitions_and_build_breadcrumbs :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> frontier:Transition_frontier.t
  -> unprocessed_transition_cache:
       Transition_handler.Unprocessed_transition_cache.t
  -> transitions:
       Mina_transition__External_transition.external_transition
       Mina_base.State_hash.With_state_hashes.t
       Network_peer.Envelope.Incoming.t
       list
  -> target_hash:Mina_base.State_hash.t
  -> subtrees:
       ( Mina_transition.External_transition.Initial_validated.t
         Network_peer.Envelope.Incoming.t
       , Transition_handler.Unprocessed_transition_cache.target )
       Cache_lib.Cached.t
       Rose_tree.t
       list
  -> ( Frontier_base.Breadcrumb.t
     , Transition_handler.Unprocessed_transition_cache.target )
     Cache_lib.Cached.t
     Rose_tree.t
     list
     Async_kernel__Deferred_or_error.t

val garbage_collect_subtrees :
     logger:Logger.t
  -> subtrees:('a, 'b) Cache_lib.Cached.t Rose_tree.t list
  -> unit

val run :
     logger:Logger.t
  -> precomputed_values:Precomputed_values.t
  -> trust_system:Trust_system.t
  -> verifier:Verifier.t
  -> network:Mina_networking.t
  -> frontier:Transition_frontier.t
  -> catchup_job_reader:
       ( Mina_base.State_hash.t
       * ( Mina_transition.External_transition.Initial_validated.t
           Network_peer.Envelope.Incoming.t
         , Transition_handler.Unprocessed_transition_cache.target )
         Cache_lib.Cached.t
         Rose_tree.t
         list )
       Pipe_lib.Strict_pipe.Reader.t
  -> catchup_breadcrumbs_writer:
       ( ( Transition_frontier.Breadcrumb.t
         , Mina_base.State_hash.t )
         Cache_lib.Cached.t
         Rose_tree.t
         list
         * [ `Catchup_scheduler | `Ledger_catchup of unit Async.Ivar.t ]
       , Pipe_lib.Strict_pipe.crash Pipe_lib.Strict_pipe.buffered
       , unit )
       Pipe_lib.Strict_pipe.Writer.t
  -> unprocessed_transition_cache:
       Transition_handler.Unprocessed_transition_cache.t
  -> unit
