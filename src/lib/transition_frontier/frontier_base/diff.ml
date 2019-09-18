open Core_kernel
open Coda_base
open Coda_transition

type full

type lite

type 'repr node_representation =
  | Full : Breadcrumb.t -> full node_representation
  | Lite : External_transition.Validated.t -> lite node_representation

type ('repr, 'mutant) t =
  | New_node : 'repr_type node_representation -> ('repr_type, unit) t
  | Root_transitioned : Root_data.Transition.t -> (_, State_hash.t) t
  | Best_tip_changed : State_hash.t -> (_, State_hash.t) t

type ('repr, 'mutant) diff = ('repr, 'mutant) t

let name : type repr mutant. (repr, mutant) t -> string = function
  | Root_transitioned _ ->
      "Root_transitioned"
  | New_node _ ->
      "New_node"
  | Best_tip_changed _ ->
      "Best_tip_changed"

let key_to_yojson (type repr mutant) (key : (repr, mutant) t) =
  let json_key =
    match key with
    | New_node (Full breadcrumb) ->
        State_hash.to_yojson (Breadcrumb.state_hash breadcrumb)
    | New_node (Lite transition) ->
        State_hash.to_yojson
          (External_transition.Validated.state_hash transition)
    | Root_transitioned {new_root; garbage} ->
        `Assoc
          [ ("new_root", State_hash.to_yojson new_root.hash)
          ; ("garbage", `List (List.map ~f:State_hash.to_yojson garbage)) ]
    | Best_tip_changed breadcrumb ->
        State_hash.to_yojson breadcrumb
  in
  `List [`String (name key); json_key]

let to_lite (type mutant) (diff : (full, mutant) t) : (lite, mutant) t =
  match diff with
  | New_node (Full breadcrumb) ->
      New_node (Lite (Breadcrumb.validated_transition breadcrumb))
  | Root_transitioned r ->
      Root_transitioned r
  | Best_tip_changed b ->
      Best_tip_changed b

module Lite = struct
  type 'mutant t = (lite, 'mutant) diff

  module E = struct
    module T_binable = struct
      type t =
        | New_node of External_transition.Validated.Stable.V1.t
        | Root_transitioned of Root_data.Transition.Stable.V1.t
        | Best_tip_changed of State_hash.Stable.V1.t
      [@@deriving bin_io]
    end

    module T = struct
      type t = E : (lite, 'mutant) diff -> t

      let to_binable = function
        | E (New_node (Lite x)) ->
            T_binable.New_node x
        | E (Root_transitioned x) ->
            T_binable.Root_transitioned x
        | E (Best_tip_changed x) ->
            T_binable.Best_tip_changed x

      let of_binable = function
        | T_binable.New_node x ->
            E (New_node (Lite x))
        | T_binable.Root_transitioned x ->
            E (Root_transitioned x)
        | T_binable.Best_tip_changed x ->
            E (Best_tip_changed x)
    end

    include T
    include Binable.Of_binable (T_binable) (T)
  end
end

module Full = struct
  type 'mutant t = (full, 'mutant) diff

  module E = struct
    type t = E : (full, 'mutant) diff -> t

    let to_lite (E diff) = Lite.E.E (to_lite diff)
  end
end
