open Core_kernel
open Coda_base
open Module_version

module Make (Inputs : Inputs.With_breadcrumb_intf) :
  Coda_intf.Transition_frontier_diff_intf
  with type breadcrumb := Inputs.Breadcrumb.t
   and type external_transition_validated := Inputs.External_transition.Validated.t
   and type scan_state := Inputs.Staged_ledger.Scan_state.t = struct
  open Inputs

  type full
  type lite

  type 'repr node_representation =
    | Full : Breadcrumb.t -> full node_representation
    | Lite : (External_transition.Validated.t, State_hash.t) With_hash.t -> lite node_representation

  module Minimal_root_data = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = 
            { hash: State_hash.Stable.V1.t
            ; scan_state: Staged_ledger.Scan_state.Stable.V1.t
            ; pending_coinbase: Pending_coinbase.Stable.V1.t }
          [@@deriving bin_io, version]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transition_frontier_minimal_root_data"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    include Stable.Latest
  end

  module Root_transition = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t =
            { new_root: Minimal_root_data.Stable.V1.t
            ; garbage: State_hash.Stable.V1.t list }
          [@@deriving bin_io, version]
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transition_frontier_root_transition"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    include Stable.Latest
  end

  type ('repr, 'mutant) t =
    | New_node : 'repr_type node_representation -> ('repr_type, unit) t
    | Root_transitioned : Root_transition.t -> (_, State_hash.t) t
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
      | New_node (Lite transition_with_hash) ->
          State_hash.to_yojson (With_hash.hash transition_with_hash)
      | Root_transitioned {new_root; garbage} ->
          `Assoc
            [ ("new_root", State_hash.to_yojson new_root.hash)
            ; ( "garbage"
              , `List
                  (List.map
                     ~f:State_hash.to_yojson
                     garbage) ) ]
      | Best_tip_changed breadcrumb -> State_hash.to_yojson breadcrumb
    in
    `List [`String (name key); json_key]

  let to_lite (type mutant) (diff : (full, mutant) t) : (lite, mutant) t =
    match diff with
    | New_node (Full breadcrumb) -> New_node (Lite (Breadcrumb.transition_with_hash breadcrumb))
    | Root_transitioned r -> Root_transitioned r
    | Best_tip_changed b -> Best_tip_changed b

  module Lite = struct
    type 'mutant t = (lite, 'mutant) diff

    module E = struct
      module T_binable = struct
        type t =
          | New_node of (External_transition.Validated.t, State_hash.Stable.V1.t) With_hash.Stable.V1.t
          | Root_transitioned of Root_transition.t
          | Best_tip_changed of State_hash.Stable.V1.t
        [@@deriving bin_io]
      end

      module T = struct
        type t = E : (lite, 'mutant) diff -> t

        let to_binable = function
          | E (New_node (Lite x))    -> T_binable.New_node x
          | E (Root_transitioned x) -> T_binable.Root_transitioned x
          | E (Best_tip_changed x)  -> T_binable.Best_tip_changed x

        let of_binable = function
          | T_binable.New_node x    -> E (New_node (Lite x))
          | T_binable.Root_transitioned x -> E (Root_transitioned x)
          | T_binable.Best_tip_changed x  -> E (Best_tip_changed x)
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
end
