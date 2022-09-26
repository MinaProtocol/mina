open Mina_base
open Core_kernel

module type CONTEXT = sig
  include Transition_handler.Validator.CONTEXT

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
end

let genesis_state_hash (module Context : CONTEXT) =
  let genesis_protocol_state =
    Precomputed_values.genesis_state_with_hashes Context.precomputed_values
  in
  State_hash.With_state_hashes.state_hash genesis_protocol_state

let state_functions =
  (module Transition_state.State_functions : Substate.State_functions
    with type state_t = Transition_state.t )

type catchup_state =
  { transition_states : Transition_state.t State_hash.Table.t
        (* Map from parent to list of children for children whose parent
           is not in the transition states *)
  ; orphans : State_hash.t list State_hash.Table.t
  }

let state_hash_of_header_with_validation hv =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.header_with_hash hv)

let state_hash_of_block_with_validation block =
  State_hash.With_state_hashes.state_hash
    (Mina_block.Validation.block_with_hash block)

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
