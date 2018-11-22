open Core_kernel
open Async_kernel

module Make_base
    (Key : Intf.Key)
    (Account : Intf.Account with type key := Key.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Location : Location_intf.S)
    (Depth : sig val depth : int end)
= struct
  module type Base_intf =
    Base_ledger_intf.S
          with module Addr = Location.Addr
          with module Location = Location
          with type key := Key.t
           and type hash := Hash.t
           and type root_hash := Hash.t
           and type account := Account.t

  type witness =
    T : (module Base_intf with type t = 't) * 't -> witness

  module M : (Base_intf with type t = witness) = struct
    type t = witness
    type index = int

    module Location = Location
    module Path = Merkle_path.Make (Hash)
    type path = Path.t
    module Addr = Location.Addr

    let copy (T ((module Base), t)) =
      T ((module Base), Base.copy t)

    let remove_accounts_exn (T ((module Base), t)) =
      Base.remove_accounts_exn t

    let merkle_path_at_index_exn (T ((module Base), t)) =
      Base.merkle_path_at_index_exn t

    let merkle_path (T ((module Base), t)) =
      Base.merkle_path t

    let merkle_root (T ((module Base), t)) =
      Base.merkle_root t

    let index_of_key_exn (T ((module Base), t)) =
      Base.index_of_key_exn t

    let set_at_index_exn (T ((module Base), t)) =
      Base.set_at_index_exn t

    let get_at_index_exn (T ((module Base), t)) =
      Base.get_at_index_exn t

    let set_batch (T ((module Base), t)) =
      Base.set_batch t

    let set (T ((module Base), t)) =
      Base.set t

    let get (T ((module Base), t)) =
      Base.get t

    let get_uuid (T ((module Base), t)) =
      Base.get_uuid t

    let destroy (T ((module Base), t)) =
      Base.destroy t

    let get_or_create_account_exn (T ((module Base), t)) =
      Base.get_or_create_account_exn t

    let get_or_create_account (T ((module Base), t)) =
      Base.get_or_create_account t

    let location_of_key (T ((module Base), t)) =
      Base.location_of_key t

    let fold_until (T ((module Base), t)) =
      Base.fold_until t

    let foldi (T ((module Base), t)) =
      Base.foldi t

    let to_list (T ((module Base), t)) =
      Base.to_list t

    let make_space_for (T ((module Base), t)) =
      Base.make_space_for t

    let get_all_accounts_rooted_at_exn (T ((module Base), t)) =
      Base.get_all_accounts_rooted_at_exn t

    let set_all_accounts_rooted_at_exn (T ((module Base), t)) =
      Base.set_all_accounts_rooted_at_exn t

    let set_inner_hash_at_addr_exn (T ((module Base), t)) =
      Base.set_inner_hash_at_addr_exn t

    let get_inner_hash_at_addr_exn (T ((module Base), t)) =
      Base.get_inner_hash_at_addr_exn t

    let merkle_path_at_addr_exn (T ((module Base), t)) =
      Base.merkle_path_at_addr_exn t

    let num_accounts (T ((module Base), t)) =
      Base.num_accounts t

    (* This better be the same depth inside Base or you're going to have a bad
     * time *)
    let depth = Depth.depth
  end
end

