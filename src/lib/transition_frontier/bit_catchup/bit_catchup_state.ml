open Core_kernel
open Mina_base
module Length_map = Length_map
module Substate_types = Substate_types
module Transition_state = Transition_state
module Transition_states = Transition_states
module Gossip_types = Gossip_types
module Known_body_refs = Known_body_refs

type create_args_t =
  Transition_states.t
  * Known_body_refs.t
  * Lmdb_storage.Block.t
  * Lmdb_storage.Header.t

type block_storage_actions =
  { add_body : Staged_ledger_diff.Body.t -> unit
  ; remove_body : Consensus.Body_reference.t list -> unit
  }

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
  ; parents : (State_hash.t * Network_peer.Peer.t) State_hash.Table.t
        (** Map from transition's state_hash to parent for transitions that are not in transition states.
    This map is like a cache for old methods of getting transition chain. *)
  ; mutable transition_hashes_by_length :
      State_hash.t list Mina_numbers.Length.Map.t
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
  ; block_storage : Lmdb_storage.Block.t
  ; header_storage : Lmdb_storage.Header.t
  ; known_body_refs : Known_body_refs.t
  ; block_storage_actions : block_storage_actions
  }

type extended_t = t * Mina_block.Header.with_hash list

let max_catchup_chain_length state =
  (* Find the longest directed path *)
  let visited = State_hash.Table.create () in
  let rec longest_starting_at st =
    let meta = Transition_state.State_functions.transition_meta st in
    Option.value_map ~f:const
      (State_hash.Table.find visited meta.state_hash)
      ~default:(fun () ->
        let n =
          Option.value_map ~default:1
            ~f:(Fn.compose Int.succ longest_starting_at)
            (Transition_states.find state.transition_states
               meta.parent_state_hash )
        in
        State_hash.Table.set visited ~key:meta.state_hash ~data:n ;
        n )
      ()
  in
  Transition_states.fold state.transition_states ~init:0
    ~f:(Fn.compose Int.max longest_starting_at)

let breadcrumb_length =
  Fn.compose Consensus.Data.Consensus_state.blockchain_length
    Frontier_base.Breadcrumb.consensus_state

let extract_structures ~is_in_frontier transition_states =
  let transition_hashes_by_length = ref Mina_numbers.Length.Map.empty in
  let breadcrumb_queue = Queue.create () in
  let children = State_hash.Table.create () in
  (* TODO Consider properly checking transitions against root and removing it immediately.
     Now this is heuristically managed by prunning by root length. *)
  Transition_states.iter transition_states ~f:(fun st ->
      let meta = Transition_state.State_functions.transition_meta st in
      transition_hashes_by_length :=
        Mina_numbers.Length.Map.add_multi
          !transition_hashes_by_length
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
  (children, !transition_hashes_by_length, Queue.of_array arr)

let rec remove_tree ?body_ref ~logger ~state state_hash =
  let { transition_states
      ; children
      ; parents
      ; known_body_refs
      ; block_storage
      ; header_storage
      ; block_storage_actions
      ; _
      } =
    state
  in
  let f = remove_tree ~logger ~state in
  let children' =
    Option.value_map ~default:[] ~f:snd
    @@ State_hash.Table.find_and_remove children state_hash
  in
  State_hash.Table.remove parents state_hash ;
  let body_ref =
    match body_ref with
    | None ->
        Option.(
          Transition_states.find transition_states state_hash
          >>= Transition_state.header >>| With_hash.data
          >>| Mina_block.Header.body_reference)
    | x ->
        x
  in
  let (`Removal_triggered body_ref) =
    Known_body_refs.prune known_body_refs ~logger ~block_storage ~header_storage
      ?body_ref state_hash
  in
  Option.iter body_ref
    ~f:(Fn.compose block_storage_actions.remove_body List.return) ;
  Option.iter (Transition_states.find transition_states state_hash)
    ~f:(fun st ->
      ignore (Transition_state.shutdown_in_progress st : Transition_state.t) ;
      Transition_states.remove ~reason:`Prunning transition_states state_hash ;
      let children = Transition_state.children st in
      State_hash.Set.iter ~f children.processing_or_failed ;
      State_hash.Set.iter ~f children.waiting_for_parent ;
      State_hash.Set.iter ~f children.processed ) ;
  List.iter ~f children'

let prune_by_length ~logger ~state ~root_hash root_length =
  let old_hashes =
    Mina_numbers.Length.Map.to_sequence ~order:`Decreasing_key
      ~keys_less_or_equal_to:root_length state.transition_hashes_by_length
    |> Sequence.to_list |> List.concat_map ~f:snd
    |> List.filter ~f:(Fn.compose not @@ State_hash.equal root_hash)
  in
  List.iter old_hashes ~f:(remove_tree ~logger ~state)

let create ~root ~logger ~is_in_frontier transition_states ~block_storage
    ~block_storage_actions ~iter_frontier ~is_header_relevant ~header_storage
    ~known_body_refs =
  let for_removal length =
    Mina_numbers.Length.(breadcrumb_length root >= length)
  in
  let no_body body_ref =
    Lmdb_storage.Block.get_status ~logger block_storage body_ref
    |> Option.is_none
  in
  let references_to_remove = ref [] in
  let add_ref_to_remove state_hash body_ref prune =
    Known_body_refs.add_new ~no_log_on_invalid:true ~logger known_body_refs
      body_ref state_hash ;
    references_to_remove :=
      (state_hash, body_ref, prune) :: !references_to_remove
  in
  let with_hash state_hash data =
    { With_hash.data
    ; hash = { state_hash; State_hash.State_hashes.state_body_hash = None }
    }
  in
  let for_catchup = ref [] in
  Lmdb_storage.Header.iter header_storage ~f:(fun state_hash -> function
    | Header h when not (is_header_relevant ~root (with_hash state_hash h)) ->
        let body_ref = Mina_block.Header.body_reference h in
        if no_body body_ref then `Remove_continue
        else (
          add_ref_to_remove state_hash body_ref true ;
          `Continue )
    | Header h
      when (not (is_in_frontier state_hash))
           && Option.is_none
                (Transition_states.find transition_states state_hash) ->
        for_catchup := with_hash state_hash h :: !for_catchup ;
        `Continue
    | Invalid { body_ref = None; blockchain_length; _ }
      when for_removal blockchain_length ->
        `Remove_continue
    | Invalid { body_ref = Some body_ref; blockchain_length; _ }
      when for_removal blockchain_length ->
        if no_body body_ref then `Remove_continue
        else (
          add_ref_to_remove state_hash body_ref true ;
          `Continue )
    | Invalid { body_ref; blockchain_length; parent_state_hash } ->
        Option.iter body_ref ~f:(fun body_ref ->
            if not (no_body body_ref) then
              add_ref_to_remove state_hash body_ref false ) ;
        let transition_meta =
          { Substate_types.blockchain_length; parent_state_hash; state_hash }
        in
        let error = Error.of_string "invalid loaded from header storage" in
        Transition_states.add_new transition_states
          (Transition_state.Invalid { transition_meta; error }) ;
        `Continue
    | Header _ ->
        `Continue ) ;
  iter_frontier ~f:(fun breadcrumb ->
      let block = Frontier_base.Breadcrumb.block breadcrumb in
      let header = Mina_block.header block in
      let state_hash = Frontier_base.Breadcrumb.state_hash breadcrumb in
      let body_ref = Mina_block.Header.body_reference header in
      let add_body () =
        Known_body_refs.add_new ~logger known_body_refs body_ref state_hash ;
        match Lmdb_storage.Block.get_status ~logger block_storage body_ref with
        | Some Full ->
            ()
        | _ ->
            block_storage_actions.add_body (Mina_block.body block)
      in
      match Lmdb_storage.Header.get header_storage state_hash with
      | None ->
          Lmdb_storage.Header.set header_storage state_hash (Header header) ;
          add_body ()
      | Some (Header _) ->
          add_body ()
      | _ ->
          () ) ;
  List.iter !references_to_remove ~f:(fun (state_hash, body_ref, prune) ->
      let need_removal =
        if prune then
          let (`Removal_triggered body_ref_opt) =
            Known_body_refs.prune known_body_refs ~logger ~block_storage
              ~header_storage ~body_ref state_hash
          in
          Option.is_some body_ref_opt
        else
          let `Body_present _, `Removal_triggered need_removal =
            Known_body_refs.remove_reference known_body_refs ~logger
              ~block_storage body_ref state_hash
          in
          need_removal
      in
      if need_removal then block_storage_actions.remove_body [ body_ref ] ) ;
  let children, transition_hashes_by_length, breadcrumb_queue =
    extract_structures ~is_in_frontier transition_states
  in
  let state =
    { transition_states
    ; parents = State_hash.Table.create ()
    ; transition_hashes_by_length
    ; children
    ; breadcrumb_queue
    ; header_storage
    ; block_storage
    ; known_body_refs
    ; block_storage_actions
    }
  in
  prune_by_length ~logger ~state
    ~root_hash:(Frontier_base.Breadcrumb.state_hash root)
    (breadcrumb_length root) ;
  (state, !for_catchup)

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
              (Transition_state.State_functions.name st)
              ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ] )
    | E (Root_transitioned { new_root; garbage = Full hs; _ }) ->
        let root_validated =
          Frontier_base.Root_data.Limited.transition new_root
        in
        let root_length =
          Mina_block.Validated.header root_validated
          |> Mina_block.Header.blockchain_length
        in
        prune_by_length ~logger ~state
          ~root_hash:(Mina_block.Validated.state_hash root_validated)
          root_length ;
        List.iter hs ~f:(fun node ->
            let transition = node.transition in
            let body_ref =
              Mina_block.Validated.header transition
              |> Mina_block.Header.body_reference
            in
            remove_tree ~logger ~state ~body_ref
              (Mina_block.Validated.state_hash transition) )
    | E (Best_tip_changed _) ->
        () )

let add_new t st =
  Transition_states.add_new t.transition_states st ;
  let meta = Transition_state.State_functions.transition_meta st in
  let key = meta.blockchain_length in
  t.transition_hashes_by_length <-
    Mina_numbers.Length.Map.add_multi t.transition_hashes_by_length ~key
      ~data:meta.state_hash

let mark_invalid ~state ?reason ~error state_hash =
  Transition_states.mark_invalid ?reason ~error ~state_hash
    state.transition_states
  |> List.iter ~f:(fun meta ->
         State_hash.Table.change state.children
           meta.Substate_types.parent_state_hash ~f:(function
           | Some (`Invalid_children, lst) ->
               Some (`Invalid_children, meta.state_hash :: lst)
           | other ->
               other ) )
