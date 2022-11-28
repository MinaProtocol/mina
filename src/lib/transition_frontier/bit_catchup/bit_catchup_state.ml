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
  ; parents : State_hash.t State_hash.Table.t
        (** Map from transition's state_hash to parent for transitions that are not in transition states.
    This map is like a cache for old methods of getting transition chain. *)
  ; transition_hashes_by_length : State_hash.t list Mina_numbers.Length.Table.t
        (** Multi-map from blockchain length to list of state hashes contained in [transition_states]
      field that have this blockchain length *)
  ; children :
      ( [ `Orphans | `Parent_in_frontier | `Invalid_children ]
      * State_hash.t list )
      State_hash.Table.t
        (** Multi-map from parent to children. It's used to handle three cases distinguished by tag:
            * [`Orphans] when parent is neither in transition states nor in frontier
            * [`Parent_in_frontier] when parent is in frontier
            * [`Invalid_children] when parent is in transition states, in this case only
            children in [Invalid] state are kept *)
  ; breadcrumb_queue :
      ([ `Catchup | `Gossip | `Internal ] * Frontier_base.Breadcrumb.t) Queue.t
        (** Queue of breadcrumbs to be processed  *)
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

let breadcrumb_length =
  Fn.compose Consensus.Data.Consensus_state.blockchain_length
    Frontier_base.Breadcrumb.consensus_state

let extract_structures ~is_in_frontier transition_states =
  let transition_hashes_by_length = Mina_numbers.Length.Table.create () in
  let breadcrumb_queue = Queue.create () in
  let children = State_hash.Table.create () in
  Transition_states.iter transition_states ~f:(fun st ->
      let meta = Transition_state.State_functions.transition_meta st in
      Mina_numbers.Length.Table.add_multi transition_hashes_by_length
        ~key:meta.blockchain_length ~data:meta.state_hash ;
      let parent_hash = meta.parent_state_hash in
      let tag =
        if
          Option.is_some @@ Transition_states.find transition_states parent_hash
        then `Invalid_children
        else if is_in_frontier parent_hash then `Parent_in_frontier
        else `Orphans
      in
      let f =
        Fn.compose Option.some
        @@ Option.value_map
             ~default:(tag, [ meta.state_hash ])
             ~f:(Tuple2.map_snd ~f:(List.cons meta.state_hash))
      in
      ( match st with
      | Waiting_to_be_added_to_frontier { breadcrumb; source; _ } ->
          Queue.enqueue breadcrumb_queue (source, breadcrumb)
      | _ ->
          () ) ;
      match (tag, st) with
      | `Invalid_children, Invalid _ ->
          State_hash.Table.change children parent_hash ~f
      | `Invalid_children, _ ->
          ()
      | _ ->
          State_hash.Table.change children parent_hash ~f ) ;
  let arr = Queue.to_array breadcrumb_queue in
  Array.sort arr ~compare:(fun (_, b1) (_, b2) ->
      Mina_numbers.Length.compare (breadcrumb_length b1) (breadcrumb_length b2) ) ;
  (children, transition_hashes_by_length, Queue.of_array arr)

let rec remove_tree ~state state_hash =
  let f = remove_tree ~state in
  let st_opt = Transition_states.find state.transition_states state_hash in
  Option.iter st_opt ~f:(fun st ->
      ignore (Transition_state.shutdown_in_progress st : Transition_state.t) ;
      Transition_states.remove state.transition_states state_hash ;
      State_hash.Table.remove state.parents state_hash ;
      let children = Transition_state.children st in
      let children' =
        Option.value_map ~default:[] ~f:snd
        @@ State_hash.Table.find_and_remove state.children state_hash
      in
      State_hash.Set.iter ~f children.processing_or_failed ;
      State_hash.Set.iter ~f children.waiting_for_parent ;
      State_hash.Set.iter ~f children.processed ;
      List.iter ~f children' )

let prune_by_length ~state root_length =
  let old_hashes =
    Transition_states.fold ~init:[]
      ~f:(fun st acc ->
        let meta = Transition_state.State_functions.transition_meta st in
        ignore (Transition_state.shutdown_in_progress st : Transition_state.t) ;
        if Mina_numbers.Length.(meta.blockchain_length <= root_length) then
          meta.state_hash :: acc
        else acc )
      state.transition_states
  in
  List.iter old_hashes ~f:(remove_tree ~state)

let create ~root ~is_in_frontier transition_states =
  let children, transition_hashes_by_length, breadcrumb_queue =
    extract_structures ~is_in_frontier transition_states
  in
  let state =
    { transition_states
    ; parents = State_hash.Table.create ()
    ; transition_hashes_by_length
    ; children
    ; breadcrumb_queue
    }
  in
  prune_by_length ~state (breadcrumb_length root) ;
  state

let apply_diffs ~logger ({ transition_states; _ } as state)
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
    | E (Root_transitioned { new_root; garbage = Full hs; _ }) ->
        let root_length =
          Frontier_base.Root_data.Limited.transition new_root
          |> Mina_block.Validated.header |> Mina_block.Header.blockchain_length
        in
        prune_by_length ~state root_length ;
        List.iter
          (Frontier_base.Diff.Node_list.to_lite hs)
          ~f:(remove_tree ~state)
    | E (Best_tip_changed _) ->
        () )
