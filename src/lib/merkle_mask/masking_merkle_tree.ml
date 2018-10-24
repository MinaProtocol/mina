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
  type account = Account.t

  type hash = Hash.t

  type key = Key.t

  type location = Location.t

  module Path = Base.Path
  module Addr = Location.Addr
  module Db_error = Base.Db_error
  module For_tests = Base.For_tests

  type parent = Base.t option ref

  type t =
    { parent: parent
    ; account_tbl: Account.t Location.Table.t
    ; hash_tbl: Hash.t Addr.Table.t }

  let set_parent t parent = t.parent := Some parent

  let unset_parent t = t.parent := None

  let get_parent t = Option.value_exn !(t.parent)

  let has_parent t = Option.is_some !(t.parent)

  let create () =
    { parent= ref None
    ; account_tbl= Location.Table.create ()
    ; hash_tbl= Addr.Table.create () }

  (* getter, setter, so we don't rely on a particular implementation *)
  let find_account t location = Location.Table.find t.account_tbl location

  let set_account t location account =
    Location.Table.set t.account_tbl ~key:location ~data:account

  let remove_account t location = Location.Table.remove t.account_tbl location

  (* don't rely on a particular implementation *)
  let find_hash t address = Addr.Table.find t.hash_tbl address

  let set_hash t address hash =
    Addr.Table.set t.hash_tbl ~key:address ~data:hash

  (* a read does a lookup in the account_tbl; if that fails, delegate to parent *)
  let get t location =
    if not (has_parent t) then failwith "get: mask does not have a parent" ;
    match find_account t location with
    | Some account -> Some account
    | None -> Base.get (get_parent t) location

  (* for tests, observe whether location is in mask *)
  let location_in_mask t location = Option.is_some (find_account t location)

  (* given a Merkle path given by the mask parent and an account address, calculate addresses and hash for each node affected 
     by the account hash; that is, along the path from the account address to root
   *)
  let addresses_and_hashes_from_merkle_path t merkle_path account_address
      account_hash : (Addr.t * Hash.t) list =
    let get_addresses_hashes height accum node =
      let last_address, last_hash =
        match List.hd accum with
        | Some elt -> elt
        | None -> failwith "addresses_and_hashes_from_merkle_path: empty accum"
      in
      let next_address =
        match Addr.parent last_address with
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
      let merkle_node_address = Addr.sibling last_address in
      let mask_hash = find_hash t merkle_node_address in
      match node with
      | `Left h ->
          let sibling_hash = Option.value mask_hash ~default:h in
          (next_address, Hash.merge ~height last_hash sibling_hash) :: accum
      | `Right h ->
          let sibling_hash = Option.value mask_hash ~default:h in
          (next_address, Hash.merge ~height sibling_hash last_hash) :: accum
    in
    List.foldi merkle_path
      ~init:[(account_address, account_hash)]
      ~f:get_addresses_hashes

  (* a write writes only to the mask, parent is not involved 
     need to update both account and hash pieces of the mask
     *)
  let set t location account =
    if not (has_parent t) then failwith "set: mask does not have a parent" ;
    set_account t location account ;
    let account_address = Location.to_path_exn location in
    let account_hash = Hash.hash_account account in
    let merkle_path = Base.merkle_path (get_parent t) location in
    let addresses_and_hashes =
      addresses_and_hashes_from_merkle_path t merkle_path account_address
        account_hash
    in
    List.iter addresses_and_hashes ~f:(fun (addr, hash) -> set_hash t addr hash)

  (* if the mask's parent sets an account, we can prune an entry in the mask if the account in the parent
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

  let address_in_mask t addr = Option.is_some (find_hash t addr)

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
    Addr.Table.clear t.hash_tbl

  (* copy tables in t; use same parent *)
  let copy t =
    { t with
      account_tbl= Location.Table.copy t.account_tbl
    ; hash_tbl= Addr.Table.copy t.hash_tbl }

  (* types/modules/operations/values we delegate to parent *)

  let delegate_to_parent f t = get_parent t |> f

  let make_space_for = delegate_to_parent Base.make_space_for

  let merkle_root = delegate_to_parent Base.merkle_root

  let get_all_accounts_rooted_at_exn =
    delegate_to_parent Base.get_all_accounts_rooted_at_exn

  let set_all_accounts_rooted_at_exn =
    delegate_to_parent Base.set_all_accounts_rooted_at_exn

  let set_inner_hash_at_addr_exn =
    delegate_to_parent Base.set_inner_hash_at_addr_exn

  let get_inner_hash_at_addr_exn =
    delegate_to_parent Base.get_inner_hash_at_addr_exn

  let merkle_path_at_addr_exn = delegate_to_parent Base.merkle_path_at_addr_exn

  let num_accounts = delegate_to_parent Base.num_accounts

  let remove_accounts_exn = delegate_to_parent Base.remove_accounts_exn

  let merkle_path_at_index_exn =
    delegate_to_parent Base.merkle_path_at_index_exn

  let merkle_path = delegate_to_parent Base.merkle_path

  let get_or_create_account_exn =
    delegate_to_parent Base.get_or_create_account_exn

  let get_or_create_account = delegate_to_parent Base.get_or_create_account

  let index_of_key_exn = delegate_to_parent Base.index_of_key_exn

  let set_at_index_exn = delegate_to_parent Base.set_at_index_exn

  let get_at_index_exn = delegate_to_parent Base.get_at_index_exn

  let to_list = delegate_to_parent Base.to_list

  let destroy = delegate_to_parent Base.destroy

  let location_of_key = delegate_to_parent Base.location_of_key

  let sexp_of_location = Location.sexp_of_t

  let location_of_sexp = Location.t_of_sexp

  let depth = Base.depth
end
