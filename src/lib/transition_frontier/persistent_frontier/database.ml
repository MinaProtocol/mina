open Core
open Coda_base
open Coda_state

(* TODO: should debug assert garbage checks be added? *)
module Make (Inputs : Inputs.With_base_frontier_intf)
  : Intf.Db_intf
      with type external_transition_validated := Inputs.External_transition.Validated.t
       and type scan_state := Inputs.Staged_ledger.Scan_state.t
       and type minimal_root_data := Inputs.Frontier.Diff.minimal_root_data
       and type root_data := Inputs.Frontier.root_data
       and type frontier_hash := Inputs.Frontier.Hash.t = struct
  open Inputs
  open Result.Let_syntax

  (* TODO: implement versions with module versioning. For
   * now, this is just stubbed so we can add db migrations
   * later.
   *)
  let version = 1

  module Schema = struct
    type _ t =
      | Db_version : int t
      | Transition : State_hash.Stable.V1.t -> External_transition.Validated.Stable.V1.t t
      | Arcs : State_hash.Stable.V1.t -> State_hash.Stable.V1.t list t
      | Root : Frontier.Diff.minimal_root_data t
      | Best_tip : State_hash.Stable.V1.t t
      | Frontier_hash : Frontier.Hash.t t

    let binable_data_type (type a) : a t -> a Bin_prot.Type_class.t = function
      | Db_version ->
          [%bin_type_class: int]
      | Transition _ ->
          [%bin_type_class: External_transition.Validated.Stable.V1.t]
      | Arcs _ ->
          [%bin_type_class: State_hash.Stable.V1.t list]
      | Root ->
          [%bin_type_class: Frontier.Diff.minimal_root_data]
      | Best_tip ->
          [%bin_type_class: State_hash.Stable.V1.t]
      | Frontier_hash ->
          [%bin_type_class: Frontier.Hash.t]

    (* HACK: a simple way to derive Bin_prot.Type_class.t for each case of a GADT *)
    let gadt_input_type_class (type data a) :
           (module Binable.S with type t = data)
        -> to_gadt:(data -> a t)
        -> of_gadt:(a t -> data)
        -> a t Bin_prot.Type_class.t =
     fun (module M) ~to_gadt ~of_gadt ->
      let ({shape; writer= {size; write}; reader= {read; vtag_read}}
            : data Bin_prot.Type_class.t) =
        [%bin_type_class: M.t]
      in
      { shape
      ; writer=
          { size= Fn.compose size of_gadt
          ; write= (fun buffer ~pos gadt -> write buffer ~pos (of_gadt gadt)) }
      ; reader=
          { read= (fun buffer ~pos_ref -> to_gadt (read buffer ~pos_ref))
          ; vtag_read=
              (fun buffer ~pos_ref number ->
                to_gadt (vtag_read buffer ~pos_ref number) ) } }

    (* HACK: The OCaml compiler thought the pattern matching in of_gadts was
     non-exhaustive. However, it should not be since I constrained the
     polymorphic type *)
    let[@warning "-8"] binable_key_type (type a) :
        a t -> a t Bin_prot.Type_class.t = function
      | Db_version ->
          gadt_input_type_class
            (module Unit)
            ~to_gadt:(fun _ -> Db_version)
            ~of_gadt:(fun Db_version -> ())
      | Transition _ ->
          gadt_input_type_class
            (module State_hash.Stable.V1)
            ~to_gadt:(fun transition -> Transition transition)
            ~of_gadt:(fun (Transition transition) -> transition)
      | Arcs _ ->
          gadt_input_type_class
            (module State_hash.Stable.V1)
            ~to_gadt:(fun arcs -> Arcs arcs)
            ~of_gadt:(fun (Arcs arcs) -> arcs)
      | Root ->
          gadt_input_type_class
            (module Unit)
            ~to_gadt:(fun _ -> Root)
            ~of_gadt:(fun Root -> ())
      | Best_tip ->
          gadt_input_type_class
            (module Unit)
            ~to_gadt:(fun _ -> Best_tip)
            ~of_gadt:(fun Best_tip -> ())
      | Frontier_hash ->
          gadt_input_type_class
            (module Unit)
            ~to_gadt:(fun _ -> Frontier_hash)
            ~of_gadt:(fun Frontier_hash -> ())
  end

  module Rocks = Rocksdb.Serializable.GADT.Make (Schema)

  type t =
    { directory: string
    ; logger: Logger.t
    ; mutable db: Rocks.t }

  let create ~logger ~directory =
    (if not (Result.is_ok (Unix.access directory [`Exists])) then
      Unix.mkdir ~perm:0o766 directory);
    {directory; logger; db= Rocks.create ~directory}

  let close t = Rocks.close t.db

  (* TODO: is this safe? do we need to sync io first? *)
  let clear t =
    close t;
    Unix.remove t.directory;
    t.db <- Rocks.create ~directory:t.directory

  open Schema
  open Rocks

  let mem db ~key = Option.is_some (get db ~key)

  let get_if_exists db ~default ~key =
    match get db ~key with
    | Some x -> x
    | None   -> default

  let get db ~key ~error =
    match get db ~key with
    | Some x -> Ok x
    | None   -> Error error

  (* TODO: batch reads might be nice *)
  let check t =
    match get_if_exists t.db ~key:Db_version ~default:0 with
    | 0 -> Error `Not_initialized
    | v when v = version ->
        let%bind root = get t.db ~key:Root ~error:(`Corrupt (`Not_found `Root)) in
        let%bind best_tip = get t.db ~key:Best_tip ~error:(`Corrupt (`Not_found `Best_tip)) in
        let%bind _ = get t.db ~key:Frontier_hash ~error:(`Corrupt (`Not_found `Frontier_hash)) in
        let%bind _ = get t.db ~key:(Transition root.hash) ~error:(`Corrupt (`Not_found `Root_transition)) in
        let%map _ = get t.db ~key:(Transition best_tip) ~error:(`Corrupt (`Not_found `Best_tip_transition)) in
        ()
    | _ -> Error (`Corrupt `Invalid_version)

  let minimize_root_data _ = failwith "EZ TODO"

  let initialize t ~root_data ~base_hash =
    let open Frontier in
    let open With_hash in
    Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch ~key:Db_version ~data:version;
      Batch.set batch ~key:(Transition root_data.transition.hash) ~data:root_data.transition.data;
      Batch.set batch ~key:Root ~data:(minimize_root_data root_data);
      Batch.set batch ~key:Best_tip ~data:root_data.transition.hash;
      Batch.set batch ~key:Frontier_hash ~data:base_hash)

  let reset _ ~root_data:_ =
    (* dump the db and reinitialize *)
    failwith "TODO"

  let add t ~transition =
    let parent_hash =
      With_hash.data transition
      |> External_transition.Validated.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let node_hash = With_hash.hash transition in
    let transition = With_hash.data transition in
    let%map () =
      Result.ok_if_true (mem t.db ~key:(Transition parent_hash))
        ~error:(`Not_found `Parent_transition)
    in
    let parent_arcs =
      get_if_exists t.db
        ~key:(Arcs parent_hash)
        ~default:[]
    in
    Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch
        ~key:(Transition node_hash)
        ~data:transition;
      Batch.set batch
        ~key:(Arcs parent_hash)
      ~data:(node_hash :: parent_arcs))

  let move_root t ~new_root ~garbage =
    let open Frontier.Diff in
    let%bind () = Result.ok_if_true (mem t.db ~key:(Transition new_root.hash)) ~error:(`Not_found `New_root_transition) in
    let%map old_root = get t.db ~key:Root ~error:(`Not_found `Old_root_transition) in
    (* TODO: Result compatible rocksdb batch transaction *)
    Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch ~key:Root ~data:new_root;
      List.iter (old_root.hash :: garbage) ~f:(fun node_hash ->
        (* because we are removing entire forks of the tree, there is
         * no need to have extra logic to any remove arcs to the node
         * we are deleting since there we are deleting all of a node's
         * parents as well
         *)
        Batch.remove batch ~key:(Transition node_hash);
        Batch.remove batch ~key:(Arcs node_hash))) ;
    old_root.hash

  let get_root t =
    get t.db ~key:Root ~error:(`Not_found `Root)

  let get_root_hash t =
    let%map root = get_root t in
    root.hash

  let get_best_tip t =
    get t.db ~key:Best_tip ~error:(`Not_found `Best_tip)

  let set_best_tip t hash =
    let%map old_best_tip_hash = get_best_tip t in
    (* no need to batch because we only do one operation *)
    set t.db ~key:Best_tip ~data:hash;
    old_best_tip_hash

  let get_frontier_hash t =
    get t.db ~key:Frontier_hash ~error:(`Not_found `Frontier_hash)

  (* TODO: bundle together with other writes using batch? *)
  let set_frontier_hash t hash =
    set t.db ~key:Frontier_hash ~data:hash
end
