open Core
open Coda_base
open Protocols.Coda_transition_frontier

module type Inputs = sig
  module Scan_state : sig
    module Stable : sig
      module Latest : sig
        type t [@@deriving bin_io]
      end
    end
  end

  module External_transition : sig
    module Stable : sig
      module Latest : sig
        type t [@@deriving bin_io]
      end
    end
  end

  module Diff_hash : Diff_hash
end

module Make (Inputs : Inputs) : sig
  open Inputs

  include
    Diff_mutant
    with type external_transition := External_transition.Stable.Latest.t
     and type state_hash := State_hash.t
     and type scan_state := Scan_state.Stable.Latest.t
     and type hash := Diff_hash.t
end = struct
  open Inputs

  type serialized = string [@@deriving to_yojson]

  module Move_root = struct
    type removed_transitions = State_hash.Stable.Latest.t list
    [@@deriving to_yojson]

    type request =
      { best_tip:
          ( External_transition.Stable.Latest.t
          , State_hash.Stable.Latest.t )
          With_hash.t
      ; removed_transitions: removed_transitions
      ; new_root: State_hash.Stable.Latest.t
      ; new_scan_state: Scan_state.Stable.Latest.t }

    let request_to_yojson {best_tip; removed_transitions; new_root; _} =
      `Assoc
        [ ( "best_tip"
          , [%to_yojson: State_hash.Stable.Latest.t] (With_hash.hash best_tip)
          )
        ; ( "removed_transitions"
          , [%to_yojson: removed_transitions] removed_transitions )
        ; ("new_root", [%to_yojson: State_hash.Stable.Latest.t] new_root) ]

    type response =
      { parent: serialized
      ; removed_transitions: serialized list
      ; old_root_data: serialized }
    [@@deriving to_yojson]
  end

  (** Diff_mutant is a GADT that represents operations that affect the
      changes on the transition_frontier. Only two types of changes can occur
      when updating the transition_frontier: Add_transition and Move_root.
      Add_transition would simply add a transition to the frontier. So, the
      input of Add_transition GADT is an external_transition. After adding
      the transition, we add the transition to its parent list of successors.
      To certify that we added it to the right parent, we need some
      representation of the parent. A serialized form of the consensus_state,
      which is a string, can accomplish this. Therefore, the type of the GADT
      case will be parameterized by a string. The Move_root data type is an
      operation where we have a new best tip external_transition, remove
      external_transitions based on their state_hash and update some root
      data with new root data. Like Add_transition, we can certify that we
      added the transition into the right parent by showing the serialized
      consensus_state of the parent. We can indicate that we removed the
      external transitions with a certain state_hash by indicating the
      serialized consensus state of the transition. We can also note which
      root we are going to replace by indicating the old root *)
  type _ t =
    | Add_transition :
        ( External_transition.Stable.Latest.t
        , State_hash.Stable.Latest.t )
        With_hash.t
        -> serialized t
    | Move_root : Move_root.request -> Move_root.response t

  type e = E : 'a t -> e

  let yojson_of_value (type a) (key : a t) (value : a) =
    let name, json =
      match key with
      | Add_transition _ ->
          ("Add_transition", (`String value : Yojson.Safe.json))
      | Move_root _ -> ("Move_root", Move_root.response_to_yojson value)
    in
    `List [`String name; json]

  let yojson_of_key (type a) (key : a t) =
    let name, json =
      match key with
      | Add_transition {With_hash.hash; _} ->
          ("Add_transition", [%to_yojson: State_hash.Stable.Latest.t] hash)
      | Move_root request -> ("Move_root", Move_root.request_to_yojson request)
    in
    `List [`String name; json]

  let merge = Fn.flip Diff_hash.merge

  let hash_diff_contents (type mutant) (t : mutant t) acc =
    match t with
    | Add_transition {With_hash.hash; _} ->
        Diff_hash.merge acc (State_hash.to_bytes hash)
    | Move_root
        { best_tip= {With_hash.hash= add_transition_hash; _}
        ; removed_transitions
        ; new_root
        ; new_scan_state } ->
        let hash =
          Diff_hash.merge acc (State_hash.to_bytes add_transition_hash)
        in
        List.fold ~init:hash
          ~f:(fun acc_hash removed_transition ->
            Diff_hash.merge acc_hash (State_hash.to_bytes removed_transition)
            )
          removed_transitions
        |> merge (State_hash.to_bytes new_root)
        |> merge
             ( Bin_prot.Utils.bin_dump
                 [%bin_type_class: Scan_state.Stable.Latest.t].writer
                 new_scan_state
             |> Bigstring.to_string )

  let hash_mutant (type mutant) (t : mutant t) (mutant : mutant) acc =
    match (t, mutant) with
    | Add_transition _, parent_hash -> merge parent_hash acc
    | Move_root _, {parent; removed_transitions; old_root_data} ->
        let acc_hash = merge parent acc in
        List.fold removed_transitions ~init:acc_hash
          ~f:(fun acc_hash removed_hash -> merge removed_hash acc_hash )
        |> merge old_root_data

  let hash (type mutant) acc_hash (t : mutant t) (mutant : mutant) =
    let diff_contents_hash = hash_diff_contents t acc_hash in
    hash_mutant t mutant diff_contents_hash
end
