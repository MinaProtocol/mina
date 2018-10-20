(* merkle_masking.ml -- implements a mask in front of a Merkle tree; see RFC 0004 and docs/specs/merkle_tree.md *)

open Core

(* the type of a Merkle tree mask; it's a Merkle tree, with some additional operations *)

module Make
    (Key : Merkle_ledger.Intf.Key)
    (Account : Merkle_ledger.Intf.Account with type key := Key.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t)
    (Location : Merkle_ledger.Location_intf.S)
    (Base : Base_merkle_tree_intf.S with module Addr = Location.Addr
            with type key := Key.t
             and type hash := Hash.t
             and type location := Location.t
             and type account := Account.t) =
struct
  module For_tests = Base.For_tests
  module Path = Base.Path
  module Addr = Base.Addr
  module Db_error = Base.Db_error

  type t =
    { parent: Base.t option ref
    ; account_tbl: Account.t Location.Table.t
    ; hash_tbl: Hash.t Location.Addr.Table.t }

  let set_parent t parent = t.parent := Some parent

  let unset_parent t = t.parent := None

  let get_parent t = Option.value_exn !(t.parent)

  let create () =
    { parent= ref None
    ; account_tbl= Location.Table.create ()
    ; hash_tbl= Location.Addr.Table.create () }

  (* getter, setter, so we don't rely on a particular implementation *)
  let find_account t location = Location.Table.find t.account_tbl location

  let set_account t location account =
    Location.Table.set t.account_tbl ~key:location ~data:account

  let remove_account t location = Location.Table.remove t.account_tbl location

  (* don't rely on a particular implementation *)
  let find_hash t address = Location.Addr.Table.find t.hash_tbl address

  let set_hash t address hash =
    Location.Addr.Table.set t.hash_tbl ~key:address ~data:hash

  (* a read does a lookup in the account_tbl; if that fails, delegate to parent *)
  let get t location =
    match find_account t location with
    | Some account -> Some account
    | None -> Base.get (get_parent t) location

  (* for a Merkle path, get addresses and hash for each node
     the hash might be from the parent or the mask 
     *)
  let addresses_and_hashes_from_merkle_path t merkle_path account_address
      account_hash : (Location.Addr.t * Hash.t) list =
    let get_addresses_hashes height accum node =
      let last_address, last_hash =
        match List.hd accum with
        | Some elt -> elt
        | None -> failwith "addresses_and_hashes_from_merkle_path: empty accum"
      in
      let next_address =
        match Location.Addr.parent last_address with
        | Ok addr -> addr
        | Error _s ->
            failwith
              "addresses_and_hashes_from_merkle_path: could not get next \
               address"
      in
      (* the Merkle path is provided by the mask's parent; some hashes may be out-of-date after
         the mask is updated. Check whether our hash mask has an entry for corresponding address 
         in the path, and use it if present
         *)
      let merkle_node_address = Location.Addr.sibling last_address in
      let mask_hash = find_hash t merkle_node_address in
      match node with
      | `Left parent_hash ->
          let hash =
            match mask_hash with Some h -> h | None -> parent_hash
          in
          (next_address, Hash.merge ~height hash last_hash) :: accum
      | `Right parent_hash ->
          let hash =
            match mask_hash with Some h -> h | None -> parent_hash
          in
          (next_address, Hash.merge ~height last_hash hash) :: accum
    in
    List.foldi merkle_path
      ~init:[(account_address, account_hash)]
      ~f:get_addresses_hashes

  (* a write writes only to the mask, parent is not involved 
     need to update both account and hash pieces of the mask
     *)
  let set t location account =
    set_account t location account ;
    let account_hash = Hash.hash_account account in
    let account_address = Location.to_path_exn location in
    let merkle_path = Base.merkle_path (get_parent t) location in
    let addresses_and_hashes =
      addresses_and_hashes_from_merkle_path t merkle_path account_address
        account_hash
    in
    List.iter addresses_and_hashes ~f:(fun (addr, hash) -> set_hash t addr hash)

  (* if the mask's parent sets an account, we can prune an entry in the mask if the balance in the parent
     is the same in the mask
     *)
  let parent_set_notify t location account merkle_path =
    match find_account t location with
    | Some existing_account ->
        if Account.equal account existing_account then (
          (* optimization: remove from account table *)
          remove_account t location ;
          (* update hashes *)
          let account_address = Location.to_path_exn location in
          let account_hash = Hash.empty_account in
          let addresses_and_hashes =
            addresses_and_hashes_from_merkle_path t merkle_path account_address
              account_hash
          in
          List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
              set_hash t addr hash ) )
    | None -> ()

  (* as for accounts, we see if we have it in the mask, else delegate to parent *)
  let get_hash t addr =
    match find_hash t addr with
    | Some hash -> Some hash
    | None ->
      try
        let hash = Base.get_inner_hash_at_addr_exn (get_parent t) addr in
        Some hash
      with _ -> None

  (* batch operations
     TODO: rely on availability of batch operations in Base for speed
     *)
  (* NB: rocksdb does not support batch reads; should we offer this? *)
  let get_batch t locations =
    List.map locations ~f:(fun location -> get t location)

  (* TODO: maybe create a new hash table from the alist, then merge *)
  let set_batch _t locations_and_accounts =
    List.iter locations_and_accounts ~f:(fun (location, account) ->
        set _t location account )

  (* NB: rocksdb does not support batch reads; is this needed? *)
  let get_hash_batch t addrs =
    List.map addrs ~f:(fun addr ->
        match find_hash t addr with
        | Some account -> Some account
        | None ->
          try Some (Base.get_inner_hash_at_addr_exn (get_parent t) addr)
          with _ -> None )

  (* transfer state from mask to parent; flush local state *)
  let commit t =
    let account_data = Location.Table.to_alist t.account_tbl in
    Base.set_batch (get_parent t) account_data ;
    (* TODO: do we worry about this code being interrupted, leading to inconsistent state? *)
    Location.Table.clear t.account_tbl ;
    Location.Addr.Table.clear t.hash_tbl

  (* copy tables in t; use same parent *)
  let copy t =
    { t with
      account_tbl= Location.Table.copy t.account_tbl
    ; hash_tbl= Location.Addr.Table.copy t.hash_tbl }

  (* types/modules/operations/values we delegate to parent *)

  let make_space_for t = Base.make_space_for (get_parent t)

  let merkle_root t = Base.merkle_root (get_parent t)

  let get_all_accounts_rooted_at_exn t =
    Base.get_all_accounts_rooted_at_exn (get_parent t)

  let set_all_accounts_rooted_at_exn t =
    Base.set_all_accounts_rooted_at_exn (get_parent t)

  let set_inner_hash_at_addr_exn t =
    Base.set_inner_hash_at_addr_exn (get_parent t)

  let get_inner_hash_at_addr_exn t =
    Base.get_inner_hash_at_addr_exn (get_parent t)

  let merkle_path_at_addr_exn t = Base.merkle_path_at_addr_exn (get_parent t)

  let num_accounts t = Base.num_accounts (get_parent t)

  let remove_accounts_exn t = Base.remove_accounts_exn (get_parent t)

  let merkle_path_at_index_exn t = Base.merkle_path_at_index_exn (get_parent t)

  let merkle_path t = Base.merkle_path (get_parent t)

  let get_or_create_account_exn t =
    Base.get_or_create_account_exn (get_parent t)

  let get_or_create_account t = Base.get_or_create_account (get_parent t)

  let index_of_key_exn t = Base.index_of_key_exn (get_parent t)

  let set_at_index_exn t = Base.set_at_index_exn (get_parent t)

  let get_at_index_exn t = Base.get_at_index_exn (get_parent t)

  let to_list t = Base.to_list (get_parent t)

  let destroy t = Base.destroy (get_parent t)

  let location_of_key t = Base.location_of_key (get_parent t)

  let sexp_of_location = Location.sexp_of_t

  let location_of_sexp = Location.t_of_sexp

  let depth = Base.depth
end
