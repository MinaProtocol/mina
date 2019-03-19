(* maskable_merkle_tree.ml -- Merkle tree that can have associated masks *)

open Core

module type Inputs_intf = sig
  include Inputs_intf.S

  module Mask :
    Masking_merkle_tree_intf.S
    with module Location = Location
     and type account := Account.t
     and type location := Location.t
     and type hash := Hash.t
     and type key := Key.t
     and type key_set := Key.Set.t
     and type parent := Base.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  include Base

  let (registered_masks : Mask.Attached.t list Uuid.Table.t) =
    Uuid.Table.create ()

  module Node = struct
    type t = Mask.Attached.t

    type attached =
      {hash: string; uuid: string; total_currency: int; num_accounts: int}
    [@@deriving yojson]

    type dangling = {uuid: string} [@@deriving yojson]

    type display = [`Attached of attached | `Dangling_parent of dangling]
    [@@deriving yojson]

    let format_uuid mask =
      Visualization.display_prefix_of_string @@ Uuid.to_string
      @@ Mask.Attached.get_uuid mask

    let name mask = sprintf !"\"%s \"" (format_uuid mask)

    let display_attached_mask mask =
      let root_hash = Mask.Attached.merkle_root mask in
      let num_accounts = Mask.Attached.num_accounts mask in
      let total_currency =
        Mask.Attached.foldi mask ~init:0 ~f:(fun _ total_currency account ->
            total_currency + (Balance.to_int @@ Account.balance account) )
      in
      let uuid = format_uuid mask in
      { hash= Visualization.display_short_sexp (module Hash) root_hash
      ; num_accounts
      ; total_currency
      ; uuid }

    let display mask =
      try `Attached (display_attached_mask mask)
      with Mask.Attached.Dangling_parent_reference _ ->
        `Dangling_parent {uuid= format_uuid mask}

    let equal mask1 mask2 =
      let open Mask.Attached in
      Uuid.equal (get_uuid mask1) (get_uuid mask2)

    let compare mask1 mask2 =
      let open Mask.Attached in
      Uuid.compare (get_uuid mask1) (get_uuid mask2)

    let hash mask = Uuid.hash @@ Mask.Attached.get_uuid mask
  end

  module Graphviz = Visualization.Make_ocamlgraph (Node)

  let to_graph () =
    let masks = List.concat @@ Uuid.Table.data registered_masks in
    let uuid_to_masks_table =
      Uuid.Table.of_alist_exn
        (List.map masks ~f:(fun mask -> (Mask.Attached.get_uuid mask, mask)))
    in
    let open Graphviz in
    Uuid.Table.fold uuid_to_masks_table ~init:empty
      ~f:(fun ~key:uuid ~data:mask graph ->
        let graph_with_mask = add_vertex graph mask in
        Uuid.Table.find registered_masks uuid
        |> Option.value_map ~default:graph_with_mask ~f:(fun children_masks ->
               List.fold ~init:graph_with_mask children_masks
                 ~f:(fun graph_with_mask_and_child ->
                   add_edge graph_with_mask_and_child mask ) ) )

  module Debug = struct
    let visualize ~filename =
      Out_channel.with_file filename ~f:(fun output_channel ->
          let graph = to_graph () in
          Graphviz.output_graph output_channel graph )
  end

  module Visualize = struct
    module Summary = struct
      type t = [`Uuid of Uuid.t] * [`Hash of Hash.t] [@@deriving sexp_of]
    end

    type t = Leaf of Summary.t | Node of Summary.t * t list
    [@@deriving sexp_of]

    module type Crawler_intf = sig
      type t

      val get_uuid : t -> Uuid.t

      val merkle_root : t -> Hash.t
    end

    let rec _crawl : type a. (module Crawler_intf with type t = a) -> a -> t =
     fun (module C) c ->
      let summary =
        let uuid = C.get_uuid c in
        ( `Uuid uuid
        , `Hash
            ( try C.merkle_root c with _ ->
                Core.printf !"CAUGHT %{sexp: Uuid.t}\n%!" uuid ;
                Hash.empty_account ) )
      in
      match Uuid.Table.find registered_masks (C.get_uuid c) with
      | None -> Leaf summary
      | Some masks ->
          Node (summary, List.map masks ~f:(_crawl (module Mask.Attached)))
  end

  let register_mask t mask =
    let attached_mask = Mask.set_parent mask t in
    List.iter (Uuid.Table.data registered_masks) ~f:(fun ms ->
        List.iter ms ~f:(fun m ->
            [%test_result: bool]
              ~message:
                "We've already registered a mask with this UUID; you have a bug"
              ~expect:false
              (Uuid.equal (Mask.Attached.get_uuid m) (Mask.get_uuid mask)) ) ) ;
    (* handles cases where no entries for t, or where there are existing entries *)
    Uuid.Table.add_multi registered_masks ~key:(get_uuid t) ~data:attached_mask ;
    attached_mask

  let unregister_mask_exn (t : t) (mask : Mask.Attached.t) =
    let error_msg = "unregister_mask: no such registered mask" in
    let t_uuid = get_uuid t in
    match Uuid.Table.find registered_masks t_uuid with
    | None -> failwith error_msg
    | Some masks ->
        ( match List.find masks ~f:(fun m -> phys_equal m mask) with
        | None -> failwith error_msg
        | Some _ -> (
            let bad, good =
              List.partition_tf masks ~f:(fun m -> phys_equal m mask)
            in
            assert (List.length bad = 1) ;
            match good with
            | [] ->
                (* no other masks for this maskable *)
                Uuid.Table.remove registered_masks t_uuid
            | other_masks ->
                Uuid.Table.set registered_masks ~key:t_uuid ~data:other_masks )
        ) ;
        Mask.Attached.unset_parent mask

  (** a set calls the Base implementation set, notifies registered mask childen *)
  let set t location account =
    Base.set t location account ;
    match Uuid.Table.find registered_masks (get_uuid t) with
    | None -> ()
    | Some masks ->
        List.iter masks ~f:(fun mask ->
            Mask.Attached.parent_set_notify mask account )

  let remove_and_reparent_exn t t_as_mask ~children =
    let parent = Mask.Attached.get_parent t_as_mask in
    let merkle_root = Mask.Attached.merkle_root t_as_mask in
    (* we can only reparent if merkle roots are the same *)
    assert (Hash.equal (Base.merkle_root parent) merkle_root) ;
    let dangling_masks =
      List.map children ~f:(fun c -> unregister_mask_exn t c)
    in
    ignore (unregister_mask_exn parent t_as_mask) ;
    List.iter dangling_masks ~f:(fun m -> ignore (register_mask parent m))

  let batch_notify_mask_children t accounts =
    match Uuid.Table.find registered_masks (get_uuid t) with
    | None -> ()
    | Some masks ->
        List.iter masks ~f:(fun mask ->
            List.iter accounts ~f:(fun account ->
                Mask.Attached.parent_set_notify mask account ) )

  let set_batch t locations_and_accounts =
    Base.set_batch t locations_and_accounts ;
    batch_notify_mask_children t (List.map locations_and_accounts ~f:snd)

  let set_batch_accounts t addresses_and_accounts =
    Base.set_batch_accounts t addresses_and_accounts ;
    batch_notify_mask_children t (List.map addresses_and_accounts ~f:snd)

  let set_all_accounts_rooted_at_exn t address accounts =
    Base.set_all_accounts_rooted_at_exn t address accounts ;
    batch_notify_mask_children t accounts
end
