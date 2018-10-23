(* maskable_merkle_tree.ml -- Merkle tree that can have associated masks *)

open Core

module Make
    (Key : Merkle_ledger.Intf.Key)
    (Account : Merkle_ledger.Intf.Account with type key := Key.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t)
    (Location : Merkle_ledger.Location_intf.S)
    (Base : Base_merkle_tree_intf.S with module Addr = Location.Addr
            with type account := Account.t
             and type hash := Hash.t
             and type location := Location.t
             and type key := Key.t) (Mask : sig
        include Masking_merkle_tree_intf.S
                with type account := Account.t
                 and type location := Location.t
                 and type hash := Hash.t
                 and type key := Key.t
                 and type parent := Base.t
    end) =
struct
  include Base
  module Masking_tree = Mask

  (* registered masks *)

  let mask_children = ref []

  let register_mask t mask =
    mask_children := mask :: !mask_children ;
    Masking_tree.set_parent mask t

  let unregister_mask mask =
    match List.findi !mask_children ~f:(fun _ndx elt -> elt = mask) with
    | None -> failwith "unregister_mask: no such registered mask"
    | Some (ndx, _mask) ->
        let head, tail = List.split_n !mask_children ndx in
        (* splice out mask *)
        mask_children := List.take head (ndx - 1) @ tail ;
        Masking_tree.unset_parent mask

  (* a set calls the Base implementation set, then notifies the mask childen, if they're registered *)
  let set t location account =
    Base.set t location account ;
    List.iter !mask_children ~f:(fun child_mask ->
        let merkle_path = Base.merkle_path t location in
        Masking_tree.parent_set_notify child_mask location account merkle_path
    )
end
