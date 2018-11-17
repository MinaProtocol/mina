(* maskable_merkle_tree.ml -- Merkle tree that can have associated masks *)

open Core

module Make
    (Key : Merkle_ledger.Intf.Key)
    (Account : Merkle_ledger.Intf.Account with type key := Key.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t)
    (Location : Merkle_ledger.Location_intf.S)
    (Base : Base_merkle_tree_intf.S
            with module Addr = Location.Addr
            with type account := Account.t
             and type hash := Hash.t
             and type location := Location.t
             and type key := Key.t)
    (Mask : Masking_merkle_tree_intf.S
            with type account := Account.t
             and type location := Location.t
             and type hash := Hash.t
             and type key := Key.t
             and type parent := Base.t) =
struct
  include Base

  (* use an assoc list of (maskable, mask children) for registered masks

     because of the types used in the test stubs for the databases in the ledger tests,
     can't "derive hash" to allow using hash tables here, which would be a simpler implementation
   *)

  let (registered_masks : (t * Mask.Attached.t list) list ref) = ref []

  let register_mask t mask =
    let attached_mask = Mask.set_parent mask t in
    ( match List.Assoc.find !registered_masks ~equal:phys_equal t with
    | None ->
        (* no masks for this maskable yet *)
        registered_masks :=
          List.Assoc.add !registered_masks ~equal:phys_equal t [attached_mask]
    | Some existing_masks ->
        (* add new mask to existing ones *)
        registered_masks :=
          List.Assoc.add !registered_masks ~equal:phys_equal t
            (attached_mask :: existing_masks) ) ;
    attached_mask

  let unregister_mask_exn (t : t) (mask : Mask.Attached.t) =
    let error_msg = "unregister_mask: no such registered mask" in
    match List.Assoc.find !registered_masks ~equal:phys_equal t with
    | None -> failwith error_msg
    | Some masks ->
        ( match List.findi masks ~f:(fun _ndx m -> phys_equal m mask) with
        | None -> failwith error_msg
        | Some (ndx, _mask) -> (
            let head, tail = List.split_n masks ndx in
            (* splice out mask *)
            match List.take head (ndx - 1) @ tail with
            | [] ->
                (* no other masks for this maskable *)
                registered_masks :=
                  List.Assoc.remove !registered_masks ~equal:phys_equal t
            | other_masks ->
                registered_masks :=
                  List.Assoc.add !registered_masks ~equal:phys_equal t
                    other_masks ) ) ;
        Mask.Attached.unset_parent mask

  (** a set calls the Base implementation set, notifies registered mask childen *)
  let set t location account =
    Base.set t location account ;
    match List.Assoc.find !registered_masks ~equal:phys_equal t with
    | None -> ()
    | Some masks ->
        List.iter masks ~f:(fun mask ->
            Mask.Attached.parent_set_notify mask location account )
end
