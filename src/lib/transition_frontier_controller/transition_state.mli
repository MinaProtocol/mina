open Mina_base
open Core_kernel

(** Auxiliary data of a transition.
    
    It's used across many transition states to store details
    of how the transition was received.
*)
type aux_data =
  { received_via_gossip : bool
        (* TODO consider storing all senders and received_at times *)
  ; received_at : Time.t
  ; sender : Network_peer.Envelope.Sender.t
  }

(** Transition state type.
    
    It contains all the available information about a transition which:

        a) is known to be invalid
        b) is in the process of verification and addition to the frontier

    In case of transition being invalid, only the minimal informaton is stored.

    Transition state type is meant to be used for transitions that were received by gossip or
    that are ancestors of a transition received by gossip.
*)
type t =
  | Received of
      { header : Gossip_types.received_header
      ; substate : unit Substate_types.t
      ; aux : aux_data
      ; gossip_data : Gossip_types.transition_gossip_t
      ; body_opt : Mina_block.Body.t option
      }  (** Transition was received and awaits ancestry to also be fetched. *)
  | Verifying_blockchain_proof of
      { header : Mina_block.Validation.pre_initial_valid_with_header
      ; substate : Mina_block.initial_valid_header Substate_types.t
      ; aux : aux_data
      ; gossip_data : Gossip_types.transition_gossip_t
      ; body_opt : Mina_block.Body.t option
      ; baton : bool
      }  (** Transition goes through verification of its blockchain proof. *)
  | Downloading_body of
      { header : Mina_block.initial_valid_header
      ; substate : Mina_block.Body.t Substate_types.t
      ; aux : aux_data
      ; block_vc : Mina_net2.Validation_callback.t option
      ; baton : bool
      }  (** Transition's body download is in progress. *)
  | Verifying_complete_works of
      { block : Mina_block.initial_valid_block
      ; substate : unit Substate_types.t
      ; aux : aux_data
      ; block_vc : Mina_net2.Validation_callback.t option
      ; baton : bool
      }  (** Transition goes through verification of transaction snarks. *)
  | Building_breadcrumb of
      { block : Mina_block.initial_valid_block
      ; substate : Frontier_base.Breadcrumb.t Substate_types.t
      ; aux : aux_data
      ; block_vc : Mina_net2.Validation_callback.t option
      ; ancestors : State_hash.t Length_map.t
      }  (** Transition's breadcrumb is being built. *)
  | Waiting_to_be_added_to_frontier of
      { breadcrumb : Frontier_base.Breadcrumb.t
      ; source : [ `Catchup | `Gossip | `Internal ]
      ; children : Substate_types.children_sets
      }
      (** Transition's breadcrumb is ready and waits in queue to be added to frontier. *)
  | Invalid of
      { transition_meta : Substate_types.transition_meta; error : Error.t }
      (** Transition is invalid. *)

val name : t -> string

(** Instantiation of [Substate.State_functions] for transition state type [t].  *)
module State_functions : Substate.State_functions with type state_t = t

(** Get children sets of a transition state.

    In case of [Invalid] state, [Substate_types.empty_children_sets] is returned. *)
val children : t -> Substate_types.children_sets

(** Returns true iff the state's status is [Failed].
    
    For [Invalid] and [Waiting_to_be_added_to_frontier], [false] is returned. *)
val is_failed : t -> bool

(** Mark transition and all its descedandants invalid. *)
val mark_invalid :
     transition_states:State_functions.state_t State_hash.Table.t
  -> error:Error.t
  -> State_hash.t
  -> unit

(** Modify auxiliary data stored in the transition state. *)
val modify_aux_data : f:(aux_data -> aux_data) -> t -> t
