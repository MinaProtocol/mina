open Mina_base
open Core_kernel

(** Catchup state contains all the available information on
    every transition that is not in frontier and:

      1. was received through gossip
      or
      2. was fetched due to being an ancestor of a transition received through gossip.

    Bit-catchup algorithm runs every transition through consequent states and eventually
    adds it to frontier (if it's valid).
*)
type catchup_state =
  { transition_states : Transition_state.t State_hash.Table.t
        (** Map from a state_hash to state of the transition corresponding to it  *)
  ; orphans : State_hash.t list State_hash.Table.t
        (** Map from transition's state hash to list of its children for transitions
    that are not in the transition states *)
  ; parents : State_hash.t State_hash.Table.t
        (** Map from transition's state_hash to parent for transitions that are not in transition states.
    This map is like a cache for old methods of getting transition chain.
  *)
  }

type source_t = [ `Catchup | `Gossip | `Internal ]

type event_t =
  [ `Verified_header_relevance of
    ( unit
    , [ `Disconnected
      | `In_frontier of State_hash.t
      | `In_process of Transition_state.t ] )
    Result.t
    * Mina_block.Header.with_hash
    * Network_peer.Envelope.Sender.t
  | `Invalid_frontier_dependencies of
    [ `Already_in_frontier | `Not_selected_over_frontier_root ]
    * State_hash.t
    * Network_peer.Envelope.Sender.t ]

module type CONTEXT = sig
  include Transition_handler.Validator.CONTEXT

  val genesis_state_hash : State_hash.t

  val frontier : Transition_frontier.t

  val verifier : Verifier.t

  val time_controller : Block_time.Controller.t

  val trust_system : Trust_system.t

  val network : Mina_networking.t

  (** Callback to write verified transitions after they're added to the frontier. *)
  val write_verified_transition :
    [ `Transition of Mina_block.Validated.t ] * [ `Source of source_t ] -> unit

  (** Callback to write built breadcrumbs so that they can be added to frontier *)
  val write_breadcrumb : source_t -> Frontier_base.Breadcrumb.t -> unit

  (** Check is the body of a transition is present in the block storage, *)
  val check_body_in_storage :
    Consensus.Body_reference.t -> Staged_ledger_diff.Body.t option

  val building_breadcrumb_timeout : Core_kernel.Time.Span.t

  val ancestry_verification_timeout : Core_kernel.Time.Span.t

  val transaction_snark_verification_timeout : Core_kernel.Time.Span.t

  val bitwap_download_timeout : Core_kernel.Time.Span.t

  val peer_download_timeout : Core_kernel.Time.Span.t

  val ancestry_download_timeout : Core_kernel.Time.Span.t

  (** Download body for the given header  *)
  val download_body :
       header:Mina_block.Validation.initial_valid_with_header
    -> (module Interruptible.F)
    -> Mina_block.Body.t Or_error.t Interruptible.t

  (** Build breadcrumb for the given transition and its parent *)
  val build_breadcrumb :
       received_at:Time.t
    -> sender:Network_peer.Envelope.Sender.t
    -> parent:Frontier_base.Breadcrumb.t
    -> transition:Mina_block.Validation.almost_valid_with_block
    -> (module Interruptible.F)
    -> ( Frontier_base.Breadcrumb.t
       , [> `Invalid_staged_ledger_diff of Error.t
         | `Invalid_staged_ledger_hash of Error.t
         | `Fatal_error of exn ] )
       Result.t
       Interruptible.t

  (** Retrieve ancestors of target hash. Function returns a list of elements,
      each either header or block. List is sorted in parent-first order.

      Resulting list forms a chain of consequent headers/blocks with the last element
      corresponding to the target hash.

      Element [`Meta] is expected only if corresponding transition is already in transition states
      or frontier.
        *)
  val retrieve_chain :
       some_ancestors:State_hash.t list
    -> target:State_hash.t
    -> parent_cache:State_hash.t State_hash.Table.t
    -> sender:Network_peer.Envelope.Sender.t
    -> lookup_transition:(State_hash.t -> [ `Present | `Not_present | `Invalid ])
    -> (module Interruptible.F)
    -> ( [ `Header of Mina_block.Header.t
         | `Block of Mina_block.t
         | `Meta of Substate.transition_meta ]
       * Network_peer.Envelope.Sender.t )
       list
       Or_error.t
       Interruptible.t

  (** Batch-verify a list of blockchain proofs *)
  val verify_blockchain_proofs :
       (module Interruptible.F)
    -> Mina_block.Validation.pre_initial_valid_with_header list
    -> ( Mina_block.Validation.initial_valid_with_header list
       , [> `Invalid_proof | `Verifier_error of Error.t ] )
       Result.t
       Interruptible.t

  (** Batch-verify transaction snarks (complete works).
      
      Returns [Result.Error] when there was a failure, [Result.Ok true] if
      verification succeeded and [Result.Ok false] if verification
      finished with a negative result (one of works is invalid).
  *)
  val verify_transaction_proofs :
       (module Interruptible.F)
    -> (Ledger_proof.t * Sok_message.t) list
    -> bool Or_error.t Interruptible.t

  val processed_dsu : Processed_skipping.Dsu.t

  val record_event : event_t -> unit
end

let state_functions =
  (module Transition_state.State_functions : Substate.State_functions
    with type state_t = Transition_state.t )

let state_hash_of_header_with_validation hv =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.header_with_hash hv)

let state_hash_of_block_with_validation block =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.block_with_hash block)

(** [accept_gossip] takes validation callback and consensus state of a transition
    and accepts validation callback if a transition would be deemed relevant when
    received via gossip by another node and rejects the validation callback otherwise.
    *)
let accept_gossip ~context:(module Context : CONTEXT) ~valid_cb consensus_state
    =
  let now =
    let open Block_time in
    now Context.time_controller |> to_span_since_epoch |> Span.to_ms
  in
  match
    Consensus.Hooks.received_at_valid_time
      ~constants:Context.consensus_constants ~time_received:now consensus_state
  with
  | Ok () ->
      Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb `Accept
  | Error _ ->
      Mina_net2.Validation_callback.fire_if_not_already_fired valid_cb `Reject

let interrupt_after_timeout ~timeout interrupt_ivar =
  Async_kernel.upon (Async.at timeout)
    (Async_kernel.Ivar.fill_if_empty interrupt_ivar)
