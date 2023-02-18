open Core_kernel
open Mina_base
open Bit_catchup_state

type actions =
  { mark_invalid :
         ?reason:[ `Proof | `Signature_or_proof | `Other ]
      -> error:Error.t
      -> State_hash.t
      -> unit
        (** Mark transition and all its descedandants invalid and return
      transition metas of all transitions marked invalid
      (that were not in [Invalid] state before the call).
      
      Parent's children list if the parent is in transition states is also updated.
      *)
  ; mark_processed_and_promote : ?reason:string -> State_hash.t list -> unit
        (** [mark_processed_and_promote] takes a list of state hashes and marks corresponding
transitions processed. Then it promotes all of the transitions that can be promoted
as the result of [mark_processed].

  Pre-conditions:
   1. Order of [state_hashes] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status

  Post-condition: list returned respects parent-child relationship and parent always comes first 

This is a recursive function that is called recursively when a transition
is promoted multiple times or upon completion of deferred action.
*)
  }

let tag_to_string = function
  | `Invalid_children ->
      "invalid children"
  | `Orphans ->
      "orphans"
  | `Parent_in_frontier ->
      "parent in frontier"

let assert_tags_equal =
  Tuple2.curry
  @@ function
  | `Invalid_children, `Invalid_children ->
      ()
  | `Orphans, `Orphans ->
      ()
  | `Parent_in_frontier, `Parent_in_frontier ->
      ()
  | a, b ->
      failwith
        (sprintf "tags not equal: %s <> %s" (tag_to_string a) (tag_to_string b))

let handle_non_regular_child_with_tag ~tag ~state
    (meta : Substate.transition_meta) =
  let f = function
    | Some (tag', lst) ->
        (* TODO consider removing assert after debugging *)
        assert_tags_equal tag tag' ;
        Some (tag', meta.state_hash :: lst)
    | None ->
        Some (tag, [ meta.state_hash ])
  in
  State_hash.Table.change state.children meta.parent_state_hash ~f

let add_to_children_of_parent_in_frontier =
  handle_non_regular_child_with_tag ~tag:`Parent_in_frontier

let add_orphan = handle_non_regular_child_with_tag ~tag:`Orphans

let handle_non_regular_child ~state ~is_parent_in_frontier ~is_invalid meta =
  let handle tag = handle_non_regular_child_with_tag ~state ~tag meta in
  if
    Option.is_some
      (Transition_states.find state.transition_states meta.parent_state_hash)
  then ( if is_invalid then handle `Invalid_children )
  else if is_parent_in_frontier then handle `Parent_in_frontier
  else handle `Orphans

let is_block_not_full ~logger block_storage body_ref =
  not
    (Option.equal Lmdb_storage.Block.Root_block_status.equal (Some Full)
       (Lmdb_storage.Block.get_status ~logger block_storage body_ref) )
