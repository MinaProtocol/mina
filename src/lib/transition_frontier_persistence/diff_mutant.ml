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

    val consensus_state :
      Stable.Latest.t -> Consensus.Consensus_state.Value.Stable.V1.t
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
     and type consensus_state := Consensus.Consensus_state.Value.Stable.V1.t
end = struct
  open Inputs

  type serialized = string [@@deriving to_yojson, bin_io]

  type ('external_transition, _) t =
    | New_frontier :
        ( ( External_transition.Stable.Latest.t
          , State_hash.Stable.Latest.t )
          With_hash.t
        * Scan_state.Stable.Latest.t )
        -> ('external_transition, unit) t
    | Add_transition :
        ( External_transition.Stable.Latest.t
        , State_hash.Stable.Latest.t )
        With_hash.t
        -> ( 'external_transition
           , Consensus.Consensus_state.Value.Stable.V1.t )
           t
    | Remove_transitions :
        'external_transition list
        -> ( 'external_transition
           , Consensus.Consensus_state.Value.Stable.V1.t list )
           t
    | Update_root :
        (State_hash.Stable.Latest.t * Scan_state.Stable.Latest.t)
        -> ( 'external_transition
           , State_hash.Stable.Latest.t * Scan_state.Stable.Latest.t )
           t

  type 'external_transition e =
    | E : ('external_transition, 'ouput) t -> 'external_transition e

  let serialize_consensus_state =
    Binable.to_string (module Consensus.Consensus_state.Value.Stable.V1)

  (* Makes displaying consensus state nicely when we don't care about it's exact contents  *)
  let json_consensus_state external_transition =
    `String
      ( Digestif.SHA256.to_hex @@ Digestif.SHA256.digest_string
      @@ serialize_consensus_state external_transition )

  let name (type a) : ('external_transition, a) t -> string = function
    | New_frontier _ -> "New_frontier"
    | Add_transition _ -> "Add_transition"
    | Remove_transitions _ -> "Remove_transitions"
    | Update_root _ -> "Update_root"

  (* Yojson is not performant and should be turned off *)
  let yojson_of_value (type a) (key : ('external_transition, a) t) (value : a)
      =
    let json_value =
      match (key, value) with
      | New_frontier _, () -> `Null
      | Add_transition _, external_transition ->
          json_consensus_state external_transition
      | Remove_transitions _, removed_transitions ->
          `List (List.map removed_transitions ~f:json_consensus_state)
      | Update_root _, (old_state_hash, _) ->
          [%to_yojson: State_hash.t] old_state_hash
    in
    `List [`String (name key); json_value]

  let yojson_of_key (type a) (key : ('external_transition, a) t) ~f =
    let json_key =
      match key with
      | New_frontier (With_hash.({hash; _}), _) ->
          [%to_yojson: State_hash.t] hash
      | Add_transition With_hash.({hash; _}) -> [%to_yojson: State_hash.t] hash
      | Remove_transitions removed_transitions ->
          `List (List.map removed_transitions ~f)
      | Update_root (state_hash, _) -> [%to_yojson: State_hash.t] state_hash
    in
    `List [`String (name key); json_key]

  let merge = Fn.flip Diff_hash.merge

  let hash_root_data acc hash scan_state =
    acc
    |> merge
         ( Bin_prot.Utils.bin_dump
             [%bin_type_class:
               State_hash.Stable.Latest.t * Scan_state.Stable.Latest.t]
               .writer (hash, scan_state)
         |> Bigstring.to_string )

  let hash_diff_contents (type mutant) (t : ('external_transition, mutant) t)
      ~f acc =
    match t with
    | New_frontier ({With_hash.hash; _}, scan_state) ->
        hash_root_data acc hash scan_state
    | Add_transition {With_hash.hash; _} ->
        Diff_hash.merge acc (State_hash.to_bytes hash)
    | Remove_transitions removed_transitions ->
        List.fold removed_transitions ~init:acc ~f:(fun acc_hash transition ->
            Diff_hash.merge acc_hash (f transition) )
    | Update_root (new_hash, new_scan_state) ->
        hash_root_data acc new_hash new_scan_state

  let hash_mutant (type mutant) (t : ('external_transition, mutant) t)
      (mutant : mutant) acc =
    match (t, mutant) with
    | New_frontier _, () -> acc
    | Add_transition _, parent_external_transition ->
        merge (serialize_consensus_state parent_external_transition) acc
    | Remove_transitions _, removed_transitions ->
        List.fold removed_transitions ~init:acc
          ~f:(fun acc_hash removed_transition ->
            merge (serialize_consensus_state removed_transition) acc_hash )
    | Update_root _, (old_root, old_scan_state) ->
        hash_root_data acc old_root old_scan_state

  let hash (type mutant) acc_hash (t : ('external_transition, mutant) t) ~f
      (mutant : mutant) =
    let diff_contents_hash = hash_diff_contents ~f t acc_hash in
    hash_mutant t mutant diff_contents_hash
end
