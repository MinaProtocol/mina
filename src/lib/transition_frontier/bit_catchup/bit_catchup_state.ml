open Core_kernel
open Mina_base
module Length_map = Length_map
module Substate = Substate
module Transition_state = Transition_state
module Transition_states = Transition_states
module Gossip_types = Gossip_types

(** Catchup state contains all the available information on
    every transition that is not in frontier and:

      1. was received through gossip
      or
      2. was fetched due to being an ancestor of a transition received through gossip.

    Bit-catchup algorithm runs every transition through consequent states and eventually
    adds it to frontier (if it's valid).
*)
type t =
  { transition_states : Transition_states.t
        (** Map from a state_hash to state of the transition corresponding to it  *)
  ; orphans : State_hash.t list State_hash.Table.t
        (** Map from transition's state hash to list of its children for transitions
    that are not in the transition states *)
  ; parents : State_hash.t State_hash.Table.t
        (** Map from transition's state_hash to parent for transitions that are not in transition states.
    This map is like a cache for old methods of getting transition chain.
  *)
  }

let max_catchup_chain_length (t : t) =
  (* Find the longest directed path *)
  let visited = State_hash.Table.create () in
  let rec longest_starting_at state =
    let meta = Transition_state.State_functions.transition_meta state in
    Option.value_map ~f:const
      (State_hash.Table.find visited meta.state_hash)
      ~default:(fun () ->
        let n =
          Option.value_map ~default:1
            ~f:(Fn.compose Int.succ longest_starting_at)
            (Transition_states.find t.transition_states meta.parent_state_hash)
        in
        State_hash.Table.set visited ~key:meta.state_hash ~data:n ;
        n )
      ()
  in
  Transition_states.fold t.transition_states ~init:0
    ~f:(Fn.compose Int.max longest_starting_at)

let extract_orphans transition_states =
  (* TODO distinguish orphans and transitions with parents in frontier *)
  let orphans = State_hash.Table.create () in
  Transition_states.fold transition_states ~init:() ~f:(fun st () ->
      let meta = Transition_state.State_functions.transition_meta st in
      if
        Option.is_none
        @@ Transition_states.find transition_states meta.parent_state_hash
      then
        State_hash.Table.change orphans meta.parent_state_hash ~f:(fun prev ->
            Some (meta.state_hash :: Option.value ~default:[] prev) ) ) ;
  orphans

let create transition_states =
  { transition_states
  ; orphans = extract_orphans transition_states
  ; parents = State_hash.Table.create ()
  }

let apply_diffs ~logger { transition_states; _ }
    (ds : Frontier_base.Diff.Full.E.t list) =
  List.iter ds ~f:(function
    | E (New_node (Full b)) -> (
        let state_hash = Frontier_base.Breadcrumb.state_hash b in
        match Transition_states.find transition_states state_hash with
        | Some (Transition_state.Waiting_to_be_added_to_frontier _) | None ->
            ()
        | Some st ->
            [%log warn]
              "Unexpected incoming breadcrumb for a state $state_hash in %s \
               state"
              (Transition_state.name st)
              ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] )
    | E (Root_transitioned { new_root = _; garbage = Full _; _ }) ->
        ( (* TODO handle root transition *) )
    | E (Best_tip_changed _) ->
        () )
