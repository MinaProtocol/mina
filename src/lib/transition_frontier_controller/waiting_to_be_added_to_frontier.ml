open Core_kernel
open Context
open Mina_base

(** Promote a transition that is in [Building_breadcrumb] state with
    [Processed] status to [Waiting_to_be_added_to_frontier] state.
*)
let promote_to ~context:(module Context : CONTEXT) ~block_vc ~aux
    ~substate:{ Substate.children; status } : Transition_state.t =
  let breadcrumb =
    match status with
    | Processed b ->
        b
    | _ ->
        failwith "promote_building_breadcrumb: expected to be processed"
  in
  let consensus_state =
    Frontier_base.Breadcrumb.protocol_state_with_hashes breadcrumb
    |> With_hash.data |> Mina_state.Protocol_state.consensus_state
  in
  Option.iter block_vc ~f:(fun valid_cb ->
      accept_gossip ~context:(module Context) ~valid_cb consensus_state ) ;
  let source =
    if aux.Transition_state.received_via_gossip then `Gossip else `Catchup
  in
  Context.write_breadcrumb source breadcrumb ;
  Waiting_to_be_added_to_frontier { breadcrumb; source; children }

(** [handle_produced_transition] adds locally produced block to the catchup state *)
let handle_produced_transition ~context:(module Context : CONTEXT)
    ~transition_states breadcrumb =
  let state_hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
  Context.write_breadcrumb `Internal breadcrumb ;
  match Transition_states.find transition_states state_hash with
  (* match Hashtbl.add transition_states ~key:state_hash ~data with *)
  | None ->
      Transition_states.add_new transition_states
        (Transition_state.Waiting_to_be_added_to_frontier
           { breadcrumb
           ; source = `Internal
           ; children = Substate.empty_children_sets
           } )
  | Some _ ->
      [%log' warn Context.logger]
        "Produced breadcrumb $state_hash is already in bit-catchup state"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
