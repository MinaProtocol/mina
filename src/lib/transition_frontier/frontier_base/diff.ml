open Core_kernel
open Mina_base
open Mina_transition

type full = Full

type lite = Lite

module Node = struct
  type _ t =
    | Full : Breadcrumb.t -> full t
    | Lite : External_transition.Validated.Stable.V1.t -> lite t
end

module Node_list = struct
  type full_node =
    { transition: Mina_block.Validated.t
    ; scan_state: Staged_ledger.Scan_state.t }

  type lite_node = State_hash.t

  (* Full representation unfortunately cannot be breadcrumbs since they
   * will no longer be linked after mutation *)
  type _ t =
    | Full : full_node list -> full t
    | Lite : lite_node list -> lite t

  type 'repr node_list = 'repr t

  let to_lite =
    List.map ~f:(fun {transition; _} -> Mina_block.Validated.state_hash transition)

  module Lite = struct
    module Binable_arg = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]
        module V1 = struct
          type t = State_hash.Stable.V1.t list

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned_binable
    module Stable = struct
      module V1 = struct
        type t = lite node_list

        module T_nonbinable = struct
          type nonrec t = t

          let to_binable (Lite ls) = ls

          let of_binable ls = Lite ls
        end

        include Binable.Of_binable (Binable_arg.Stable.V1) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]
  end
end

module Root_transition = struct
  type 'repr t =
    { new_root: Root_data.Limited.Stable.V2.t
    ; garbage: 'repr Node_list.t
    ; just_emitted_a_proof: bool }

  type 'repr root_transition = 'repr t

  module Lite_binable = struct
    [%%versioned
    module Stable = struct
      [@@@no_toplevel_latest_type]
      module V3 = struct
        type t =
          { new_root: Root_data.Limited.Stable.V2.t
          ; garbage: Node_list.Lite.Stable.V1.t
          ; just_emitted_a_proof: bool }

        let to_latest = Fn.id
      end
      module V2 = struct
        type t =
          { new_root: Root_data.Limited.Stable.V1.t
          ; garbage: Node_list.Lite.Stable.V1.t
          ; just_emitted_a_proof: bool }

        let to_latest {new_root; garbage; just_emitted_a_proof} =
          let new_root = Root_data.Limited.Stable.V1.to_latest new_root in
          {V3.new_root; garbage; just_emitted_a_proof}
      end
    end]
  end

  module Lite = struct
    module Binable_arg = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]
        module V3 = struct
          type t = Lite_binable.Stable.V3.t

          let to_latest = Fn.id
        end

        module V2 = struct
          type t = Lite_binable.Stable.V2.t

          let to_latest = Lite_binable.Stable.V2.to_latest
        end
      end]
    end

    [%%versioned_binable
    module Stable = struct
      module V3 = struct
        type t = lite root_transition

        module T_nonbinable = struct
          type nonrec t = t

          let to_binable ({new_root; garbage; just_emitted_a_proof} : t) :
              Binable_arg.Stable.V3.t =
            {new_root; garbage; just_emitted_a_proof}

          let of_binable
              ({new_root; garbage; just_emitted_a_proof} :
                Binable_arg.Stable.V3.t) : t =
            {new_root; garbage; just_emitted_a_proof}
        end

        include Binable.Of_binable (Binable_arg.Stable.V3) (T_nonbinable)

        let to_latest = Fn.id
      end

      module V2 = struct
        type t = lite root_transition

        module T_nonbinable = struct
          type nonrec t = t

          let to_binable ({new_root; garbage; just_emitted_a_proof} : t) :
              Binable_arg.Stable.V2.t =
            let new_root = Root_data.Limited.Stable.V1.of_v2 new_root in
            {new_root; garbage; just_emitted_a_proof}

          let of_binable
              ({new_root; garbage; just_emitted_a_proof} :
                Binable_arg.Stable.V2.t) : t =
            let new_root = Root_data.Limited.Stable.V1.to_latest new_root in
            {new_root; garbage; just_emitted_a_proof}
        end

        include Binable.Of_binable (Binable_arg.Stable.V2) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]
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
        let x = External_transition.Validated.lower @@ External_transition.Validated.Stable.V1.to_latest transition in
        State_hash.to_yojson (Mina_block.Validated.state_hash x)
    | Root_transitioned {new_root; garbage; just_emitted_a_proof} ->
        let garbage_hashes =
          match garbage with
          | Node_list.Full nodes ->
              Node_list.to_lite nodes
          | Node_list.Lite hashes ->
              hashes
        in
        `Assoc
          [ ("new_root", State_hash.to_yojson (Root_data.Limited.hashes new_root).state_hash)
          ; ("garbage", `List (List.map ~f:State_hash.to_yojson garbage_hashes))
          ; ("just_emitted_a_proof", `Bool just_emitted_a_proof) ]
    | Best_tip_changed breadcrumb ->
        State_hash.to_yojson breadcrumb
  in
  `Assoc [(name key, json_key)]

let to_lite (type mutant) (diff : (full, mutant) t) : (lite, mutant) t =
  match diff with
  | New_node (Full breadcrumb) ->
    let external_transition = External_transition.Validated.lift @@ Breadcrumb.validated_transition breadcrumb in
      New_node (Lite (External_transition.Validated.Stable.V1.of_v2 external_transition ))
  | Root_transitioned
      {new_root; garbage= Full garbage_nodes; just_emitted_a_proof} ->
      Root_transitioned
        { new_root
        ; garbage= Lite (Node_list.to_lite garbage_nodes)
        ; just_emitted_a_proof }
  | Best_tip_changed b ->
      Best_tip_changed b

module Lite_binable = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]
    module V2 = struct
      type t =
        | New_node of External_transition.Validated.Stable.V1.t
        | Root_transitioned of Root_transition.Lite.Stable.V2.t
        | Best_tip_changed of State_hash.Stable.V1.t

      let to_latest = Fn.id
    end
  end]
end

module Lite = struct
  type 'mutant t = (lite, 'mutant) diff

  module E = struct
    module Binable_arg = struct
      [%%versioned
      module Stable = struct
        [@@@no_toplevel_latest_type]
        module V2 = struct
          type t = Lite_binable.Stable.V2.t

          let to_latest = Fn.id
        end
      end]
    end

    [%%versioned_binable
    module Stable = struct
      [@@@no_toplevel_latest_type]
      module V2 = struct
        type t = E : (lite, 'mutant) diff -> t
        module T_nonbinable = struct
          type nonrec t = t

          let to_binable = function
            | E (New_node (Lite x)) ->
                (New_node x : Binable_arg.Stable.V2.t)
            | E (Root_transitioned x) ->
                Root_transitioned x
            | E (Best_tip_changed x) ->
                Best_tip_changed x

          let of_binable = function
            | (New_node x : Binable_arg.Stable.V2.t) ->
                E (New_node (Lite x))
            | Root_transitioned x ->
                E (Root_transitioned x)
            | Best_tip_changed x ->
                E (Best_tip_changed x)
        end

        include Binable.Of_binable (Binable_arg.Stable.V2) (T_nonbinable)

        let to_latest = Fn.id
      end
    end]

    include (Stable.Latest : module type of Stable.Latest)
  end
end

module Full = struct
  type 'mutant t = (full, 'mutant) diff

  module E = struct
    type t = E : (full, 'mutant) diff -> t

    let to_lite (E diff) = Lite.E.E (to_lite diff)

    let to_yojson (E diff) = to_yojson diff
  end

  module With_mutant = struct
    type t = E : (full, 'mutant) diff * 'mutant -> t
  end
end
