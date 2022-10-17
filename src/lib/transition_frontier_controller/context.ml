open Mina_base
open Core_kernel

module type CONTEXT = sig
  include Transition_handler.Validator.CONTEXT

  val genesis_state_hash : State_hash.t

  val frontier : Transition_frontier.t

  val verifier : Verifier.t

  val time_controller : Block_time.Controller.t

  val trust_system : Trust_system.t

  val network : Mina_networking.t

  val write_verified_transition :
       [ `Transition of Mina_block.Validated.t ]
       * [ `Source of [ `Catchup | `Gossip | `Internal ] ]
    -> unit

  val write_breadcrumb : Frontier_base.Breadcrumb.t -> unit

  val timeout_controller : Timeout_controller.t

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

  val verify_blockchain_proofs :
       (module Interruptible.F)
    -> Mina_block.Validation.pre_initial_valid_with_header list
    -> ( Mina_block.Validation.initial_valid_with_header list
       , [> `Invalid_proof | `Verifier_error of Error.t ] )
       Result.t
       Interruptible.t

  val verify_transaction_proofs :
       (module Interruptible.F)
    -> (Ledger_proof.t * Sok_message.t) list
    -> bool Or_error.t Interruptible.t
end

let state_functions =
  (module Transition_state.State_functions : Substate.State_functions
    with type state_t = Transition_state.t )

type catchup_state =
  { transition_states : Transition_state.t State_hash.Table.t
  ; orphans : State_hash.t list State_hash.Table.t
        (** Map from transition's state hash to list of its children for transitions
    that are not in the transition states *)
  ; parents : State_hash.t State_hash.Table.t
        (** Map from transition's state_hash to parent for transitions that are not in transition states.
    This map is like a cache for old methods of getting transition chain.
  *)
  }

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
