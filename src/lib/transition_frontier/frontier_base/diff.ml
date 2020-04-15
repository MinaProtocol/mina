open Core_kernel
open Coda_base
open Coda_transition

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

  type lite_node = State_hash.t

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
    [%%versioned
    module Stable = struct
      module V1 = struct
        module T = struct
          (* Note: The versioning linter views this as the stable type. *)
          type t = State_hash.Stable.V1.t list
        end

        type t = lite node_list

        (* Migrate this to a new latest version and expose the underlying
           serialised type directly when this type changes.

           TODO(#4556): replace this mechanism with %%versioned_binable.
        *)
        module T_nonbinable = struct
          type nonrec t = t

          let to_binable (Lite ls) = ls

          let of_binable ls = Lite ls
        end

        include (T : module type of T with type t := T.t)

        include Binable.Of_binable (T) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]

    include Stable.Latest
  end
end

module Root_transition = struct
  type 'repr t = {new_root: Root_data.Minimal.t; garbage: 'repr Node_list.t}

  type 'repr root_transition = 'repr t

  module Lite_binable = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type t =
          { new_root: Root_data.Minimal.Stable.V1.t
          ; garbage: Node_list.Lite.Stable.V1.t }

        let to_latest = Fn.id
      end
    end]

    include struct
      type t = Stable.Latest.t =
        {new_root: Root_data.Minimal.t; garbage: Node_list.Lite.t}
    end [@ocaml.warning "-34"]
  end

  module Lite = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        module T = struct
          (* Note: The versioning linter views this as the stable type. *)
          type t = Lite_binable.Stable.V1.t
        end

        (* Migrate this to a new latest version and expose the underlying
           serialised type directly when this type changes.
        *)
        type t = lite root_transition

        module T_nonbinable = struct
          type nonrec t = t

          let to_binable ({new_root; garbage} : t) : T.t = {new_root; garbage}

          let of_binable ({new_root; garbage} : T.t) : t = {new_root; garbage}
        end

        include (T : module type of T with type t := T.t)

        include Binable.Of_binable (T) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]

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
          [ ("new_root", State_hash.to_yojson (Root_data.Minimal.hash new_root))
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

module Lite_binable = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        | New_node of External_transition.Validated.Stable.V1.t
        | Root_transitioned of Root_transition.Lite.Stable.V1.t
        | Best_tip_changed of State_hash.Stable.V1.t

      let to_latest = Fn.id
    end
  end]

  include struct
    type t = Stable.Latest.t =
      | New_node of External_transition.Validated.t
      | Root_transitioned of Root_transition.Lite.t
      | Best_tip_changed of State_hash.t
  end [@warning "-34"]
end

module Lite = struct
  type 'mutant t = (lite, 'mutant) diff

  module E = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        module T = struct
          (* Note: The versioning linter views this as the stable type. *)
          type t = Lite_binable.Stable.V1.t
        end

        type t = E : (lite, 'mutant) diff -> t

        (* Migrate this to a new latest version and expose the underlying
           serialised type directly when this type changes.
        *)
        module T_nonbinable = struct
          type nonrec t = t

          let to_binable = function
            | E (New_node (Lite x)) ->
                (New_node x : T.t)
            | E (Root_transitioned x) ->
                Root_transitioned x
            | E (Best_tip_changed x) ->
                Best_tip_changed x

          let of_binable = function
            | (New_node x : T.t) ->
                E (New_node (Lite x))
            | Root_transitioned x ->
                E (Root_transitioned x)
            | Best_tip_changed x ->
                E (Best_tip_changed x)
        end

        include (T : module type of T with type t := T.t)

        include Binable.Of_binable (T) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]

    type t = Stable.Latest.t = E : (lite, 'mutant) diff -> t

    include (Stable.Latest : module type of Stable.Latest with type t := t)
  end
end

module Full = struct
  type 'mutant t = (full, 'mutant) diff

  module E = struct
    type t = E : (full, 'mutant) diff -> t

    let to_lite (E diff) = Lite.E.E (to_lite diff)
  end

  module With_mutant = struct
    type t = E : (full, 'mutant) diff * 'mutant -> t
  end
end
