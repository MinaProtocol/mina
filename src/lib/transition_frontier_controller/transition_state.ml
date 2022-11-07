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

let name = function
  | Received _ ->
      "received"
  | Verifying_blockchain_proof _ ->
      "verifying blockchain proof"
  | Downloading_body _ ->
      "downloading body"
  | Verifying_complete_works _ ->
      "verifying complete works"
  | Building_breadcrumb _ ->
      "building breadcrumb"
  | Waiting_to_be_added_to_frontier _ ->
      "waiting to be added to frontier"
  | Invalid _ ->
      "invalid"

(** Instantiation of [Substate.State_functions] for transition state type [t].  *)
module State_functions : Substate.State_functions with type state_t = t = struct
  type state_t = t

  let modify_substate ~f:{ Substate.modifier = f } state =
    match state with
    | Received ({ substate = s; _ } as obj) ->
        let substate, v = f s in
        Some (Received { obj with substate }, v)
    | Verifying_blockchain_proof ({ substate = s; _ } as obj) ->
        let substate, v = f s in
        Some (Verifying_blockchain_proof { obj with substate }, v)
    | Downloading_body ({ substate = s; _ } as obj) ->
        let substate, v = f s in
        Some (Downloading_body { obj with substate }, v)
    | Verifying_complete_works ({ substate = s; _ } as obj) ->
        let substate, v = f s in
        Some (Verifying_complete_works { obj with substate }, v)
    | _ ->
        None

  let transition_meta st =
    let of_block = With_hash.map ~f:Mina_block.header in
    match st with
    | Received { header; _ } ->
        Substate.transition_meta_of_header_with_hash
        @@ Gossip_types.header_with_hash_of_received_header header
    | Verifying_blockchain_proof { header; _ } ->
        Substate.transition_meta_of_header_with_hash
        @@ Mina_block.Validation.header_with_hash header
    | Downloading_body { header; _ } ->
        Substate.transition_meta_of_header_with_hash
        @@ Mina_block.Validation.header_with_hash header
    | Verifying_complete_works { block; _ } ->
        Substate.transition_meta_of_header_with_hash @@ of_block
        @@ Mina_block.Validation.block_with_hash block
    | Building_breadcrumb { block; _ } ->
        Substate.transition_meta_of_header_with_hash @@ of_block
        @@ Mina_block.Validation.block_with_hash block
    | Waiting_to_be_added_to_frontier { breadcrumb; _ } ->
        Substate.transition_meta_of_header_with_hash @@ of_block
        @@ Frontier_base.Breadcrumb.block_with_hash breadcrumb
    | Invalid { transition_meta; _ } ->
        transition_meta

  let equal_state_levels a b =
    match (a, b) with
    | Received _, Received _ ->
        true
    | Verifying_blockchain_proof _, Verifying_blockchain_proof _ ->
        true
    | Downloading_body _, Downloading_body _ ->
        true
    | Verifying_complete_works _, Verifying_complete_works _ ->
        true
    | Building_breadcrumb _, Building_breadcrumb _ ->
        true
    | Waiting_to_be_added_to_frontier _, Waiting_to_be_added_to_frontier _ ->
        true
    | Invalid _, Invalid _ ->
        true
    | _, _ ->
        false
end

(** Get children sets of a transition state.

    In case of [Invalid] state, [Substate_types.empty_children_sets] is returned. *)
let children st =
  match st with
  | Received { substate = { children; _ }; _ }
  | Verifying_blockchain_proof { substate = { children; _ }; _ }
  | Downloading_body { substate = { children; _ }; _ }
  | Verifying_complete_works { substate = { children; _ }; _ }
  | Building_breadcrumb { substate = { children; _ }; _ }
  | Waiting_to_be_added_to_frontier { children; _ } ->
      children
  | Invalid _ ->
      Substate.empty_children_sets

(** Returns true iff the state's status is [Failed].
    
    For [Invalid] and [Waiting_to_be_added_to_frontier], [false] is returned. *)
let is_failed st =
  match st with
  | Received { substate = { status = Failed _; _ }; _ }
  | Verifying_blockchain_proof { substate = { status = Failed _; _ }; _ }
  | Downloading_body { substate = { status = Failed _; _ }; _ }
  | Verifying_complete_works { substate = { status = Failed _; _ }; _ }
  | Building_breadcrumb { substate = { status = Failed _; _ }; _ } ->
      true
  | _ ->
      false

(** Mark transition and all its descedandants invalid. *)
let mark_invalid ~transition_states ~error:err top_state_hash =
  let tag =
    sprintf "(from state hash %s) " (State_hash.to_base58_check top_state_hash)
  in
  let error = Error.tag ~tag err in
  let rec go = State_hash.Table.change transition_states ~f
  and f st_opt =
    let%bind.Option state = st_opt in
    let%map.Option () = match state with Invalid _ -> None | _ -> Some () in
    ( match state with
    | Received { gossip_data; _ }
    | Verifying_blockchain_proof { gossip_data; _ } ->
        Gossip_types.drop_gossip_data `Reject gossip_data
    | Downloading_body { block_vc; _ }
    | Verifying_complete_works { block_vc; _ }
    | Building_breadcrumb { block_vc; _ } ->
        Option.iter
          ~f:
            (Fn.flip Mina_net2.Validation_callback.fire_if_not_already_fired
               `Reject )
          block_vc
    | Invalid _ | Waiting_to_be_added_to_frontier _ ->
        () ) ;
    let transition_meta = State_functions.transition_meta state in
    let children = children state in
    State_hash.Set.iter children.processing_or_failed ~f:go ;
    State_hash.Set.iter children.processed ~f:go ;
    State_hash.Set.iter children.waiting_for_parent ~f:go ;
    Invalid { transition_meta; error }
  in
  go top_state_hash

(** Modify auxiliary data stored in the transition state. *)
let modify_aux_data ~f = function
  | Received ({ aux; _ } as r) ->
      Received { r with aux = f aux }
  | Verifying_blockchain_proof ({ aux; _ } as r) ->
      Verifying_blockchain_proof { r with aux = f aux }
  | Downloading_body ({ aux; _ } as r) ->
      Downloading_body { r with aux = f aux }
  | Verifying_complete_works ({ aux; _ } as r) ->
      Verifying_complete_works { r with aux = f aux }
  | Building_breadcrumb ({ aux; _ } as r) ->
      Building_breadcrumb { r with aux = f aux }
  | (Waiting_to_be_added_to_frontier _ as st) | (Invalid _ as st) ->
      st
