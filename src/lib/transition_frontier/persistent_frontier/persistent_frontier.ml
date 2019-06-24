open Core
open Coda_base
open Coda_state

(* TODO: should debug assert garbage checks be added? *)
module Make (Inputs : Inputs.With_base_frontier) = struct
  open Inputs

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
      | Root : Frontier.Diff.root_data t
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
          [%bin_type_class: Frontier.Diff.root_data]
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

  type t = {db: Rocks.t; logger: Logger.t}

  let create ~logger ~directory =
    {db= Rocks.create ~directory; logger}

  let close t = Rocks.close t.db

  open Schema
  open Rocks

  (* TODO: wrap rocksdb interface with or errors to avoid this... this shouldn't be necessary *)
  let get (type a) t ?(location = __LOC__)
      (key : a Schema.t) : a =
    match get t.db ~key with
    | Some value ->
        value
    | None -> (
        let log_error = Logger.error t.logger ~module_:__MODULE__ ~location in
        match key with
        | Db_version ->
            log_error "Could not retrieve db vesrion" ;
            raise (Not_found_s (Sexp.of_string "<Db_version>"))
        | Transition hash ->
            log_error
              ~metadata:[("hash", State_hash.to_yojson hash)]
              "Could not retrieve external transition: $hash" ;
            raise (Not_found_s (State_hash.sexp_of_t hash))
        | Arcs hash ->
            log_error
              ~metadata:[("hash", State_hash.to_yojson hash)]
              "Could not retrieve arcs: $hash" ;
            raise (Not_found_s (State_hash.sexp_of_t hash))
        | Root ->
            log_error "Could not retrieve root" ;
            raise (Not_found_s (Sexp.of_string "<Root>"))
        | Best_tip ->
            log_error "Could not retrieve best tip" ;
            raise (Not_found_s (Sexp.of_string "<Best_tip>"))
        | Frontier_hash ->
            log_error "Could not retrieve frontier hash" ;
            raise (Not_found_s (Sexp.of_string "<Frontier_hash>")))

  let get_if_exists (type a) t ~default ?(location = __LOC__) (key : a Schema.t) : a =
    try get t ~location key with Not_found_s _ -> default

  (* TODO: batch reads might be nice *)
  let check t =
    match get_if_exists t Db_version ~default:0 with
    | 0 -> Error `Not_initialized
    | v when v = version -> (
        (* TODO: should this also do a arc checks? *)
        Option.value ~default:(Error `Corrupt) (
          let open Option.Let_syntax in
          let%bind root = Rocks.get t.db ~key:Root in
          let%bind best_tip = Rocks.get t.db ~key:Best_tip in
          let%bind _ = Rocks.get t.db ~key:Frontier_hash in
          let%bind _ = Rocks.get t.db ~key:(Transition root.hash) in
          let%map _ = Rocks.get t.db ~key:(Transition best_tip) in
          Ok ()))
    | _ -> Error `Corrupt

  let initialize t ~root_transition ~root_data ~base_hash =
    let open Frontier.Diff in
    Batch.with_batch t.db ~f:(fun batch ->
      Batch.set batch ~key:Db_version ~data:version;
      Batch.set batch ~key:(Transition root_data.hash) ~data:root_transition;
      Batch.set batch ~key:Root ~data:root_data;
      Batch.set batch ~key:Best_tip ~data:root_data.hash;
      Batch.set batch ~key:Frontier_hash ~data:base_hash)

  let add t ~transition =
    let parent_hash =
      With_hash.data transition
      |> External_transition.Validated.protocol_state
      |> Protocol_state.previous_state_hash
    in
    let node_hash = With_hash.hash transition in
    let transition = With_hash.data transition in
    let parent_arcs =
      get_if_exists t
        (Arcs parent_hash)
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
    let old_root = get t Root in
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

  let set_best_tip t hash =
    let old_best_tip_hash = get t ~key:Best_tip in
    (* no need to batch because we only do one operation *)
    set t.db ~key:Best_tip ~data:hash;
    old_best_tip_hash

  (* TODO: bundle together with other writes using batch? *)
  let set_frontier_hash t hash =
    set t.db ~key:Frontier_hash ~data:hash
end
