open Core_kernel
open Coda_base
open Coda_transition
open Module_version

type full

type lite

module Node = struct
  type _ t =
    | Full : Breadcrumb.t -> full t
    | Lite : External_transition.Validated.t -> lite t
end

module Node_list = struct
  type full_node =
    { transition: External_transition.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t }

  type lite_node = State_hash.Stable.V1.t

  (* Full representation unfortunately cannot be breadcrumbs since they
   * will no longer be linked after mutation *)
  type _ t =
    | Full : full_node list -> full t
    | Lite : lite_node list -> lite t

  type 'repr node_list = 'repr t

  let to_lite =
    let f {transition; _} =
      External_transition.Validated.state_hash transition
    in
    List.map ~f

  module Lite = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          module T_binable = struct
            type t = State_hash.Stable.V1.t list [@@deriving bin_io]
          end

          module T_nonbinable = struct
            type t = lite node_list

            let to_binable (Lite ls) = ls

            let of_binable ls = Lite ls
          end

          type t = T_nonbinable.t [@@deriving version {asserted}]

          include Binable.Of_binable (T_binable) (T_nonbinable)
        end

        include T
        include Registration.Make_latest_version (T)
      end

      module Latest = V1

      module Module_decl = struct
        let name = "transition_frontier_diff_node_list"

        type latest = Latest.t
      end

      module Registrar = Registration.Make (Module_decl)
      module Registered_V1 = Registrar.Register (V1)
    end

    include Stable.Latest
  end
end

module Root_transition = struct
  type 'repr t =
    {new_root: Root_data.Minimal.Stable.V1.t; garbage: 'repr Node_list.t}

  type 'repr root_transition = 'repr t

  module Lite = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          module T_binable = struct
            type t =
              { new_root: Root_data.Minimal.Stable.V1.t
              ; garbage: Node_list.Lite.Stable.V1.t }
            [@@deriving bin_io]
          end

          module T_nonbinable = struct
            type t = lite root_transition

            let to_binable {new_root; garbage} = {T_binable.new_root; garbage}

            let of_binable {T_binable.new_root; garbage} = {new_root; garbage}
          end

          type t = T_nonbinable.t [@@deriving version {asserted}]

          include Binable.Of_binable (T_binable) (T_nonbinable)
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
end

type ('repr, 'mutant) t =
  | New_node : 'repr Node.t -> ('repr, unit) t
  | Root_transitioned : 'repr Root_transition.t -> ('repr, State_hash.t) t
  | Best_tip_changed : State_hash.t -> (_, State_hash.t) t

type ('repr, 'mutant) diff = ('repr, 'mutant) t

let name : type repr mutant. (repr, mutant) t -> string = function
  | Root_transitioned _ ->
      "Root_transitioned"
  | New_node _ ->
      "New_node"
  | Best_tip_changed _ ->
      "Best_tip_changed"

let to_yojson (type repr mutant) (key : (repr, mutant) t) =
  let json_key =
    match key with
    | New_node (Full breadcrumb) ->
        State_hash.to_yojson (Breadcrumb.state_hash breadcrumb)
    | New_node (Lite transition) ->
        State_hash.to_yojson
          (External_transition.Validated.state_hash transition)
    | Root_transitioned {new_root; garbage} ->
        let garbage_hashes =
          match garbage with
          | Node_list.Full nodes ->
              Node_list.to_lite nodes
          | Node_list.Lite hashes ->
              hashes
        in
        `Assoc
          [ ("new_root", State_hash.to_yojson new_root.hash)
          ; ("garbage", `List (List.map ~f:State_hash.to_yojson garbage_hashes))
          ]
    | Best_tip_changed breadcrumb ->
        State_hash.to_yojson breadcrumb
  in
  `Assoc [(name key, json_key)]

let to_lite (type mutant) (diff : (full, mutant) t) : (lite, mutant) t =
  match diff with
  | New_node (Full breadcrumb) ->
      New_node (Lite (Breadcrumb.validated_transition breadcrumb))
  | Root_transitioned {new_root; garbage= Full garbage_nodes} ->
      Root_transitioned
        {new_root; garbage= Lite (Node_list.to_lite garbage_nodes)}
  | Best_tip_changed b ->
      Best_tip_changed b

module Lite = struct
  type 'mutant t = (lite, 'mutant) diff

  module E = struct
    module T_binable = struct
      type t =
        | New_node of External_transition.Validated.Stable.V1.t
        | Root_transitioned of Root_transition.Lite.Stable.V1.t
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
