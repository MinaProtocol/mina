(* masking_merkle_tree.ml -- implements a mask in front of a Merkle tree; see RFC 0004 and docs/specs/merkle_tree.md *)

open Core

(* builds a Merkle tree mask; it's a Merkle tree, with some additional operations *)
module Make
    (Key : Merkle_ledger.Intf.Key)
    (Account : Merkle_ledger.Intf.Account with type key := Key.t)
    (Hash : Merkle_ledger.Intf.Hash with type account := Account.t)
    (Location : Merkle_ledger.Location_intf.S)
    (Base : Base_merkle_tree_intf.S
            with module Addr = Location.Addr
             and module Location = Location
            with type key := Key.t
             and type key_set := Key.Set.t
             and type hash := Hash.t
             and type root_hash := Hash.t
             and type account := Account.t) =
struct
  type account = Account.t

  type hash = Hash.t

  type key = Key.t

  type key_set = Key.Set.t

  type location = Location.t

  module Location = Location
  module Addr = Location.Addr

  (** Invariant is that parent is None in unattached mask
   * and `Some` in the attached one
   * We can capture this with a GADT but there's some annoying
   * issues with bin_io to do so *)
  module Parent = struct
    module T = struct
      type t = Base.t option [@@deriving sexp]
    end

    include T

    include Binable.Of_binable
              (Unit)
              (struct
                include T

                let to_binable = function
                  | Some _ ->
                      failwith "We can't serialize when we're an attached mask"
                  | None -> ()

                let of_binable () = None
              end)
  end

  type t =
    { uuid: Uuid.Stable.V1.t
    ; account_tbl: Account.t Location.Table.t
    ; mutable parent: Parent.t
    ; hash_tbl: Hash.t Addr.Table.t
    ; location_tbl: Location.t Key.Table.t
    ; mutable current_location: Location.t option }
  [@@deriving sexp, bin_io]

  type unattached = t [@@deriving sexp]

  let create () =
    { uuid= Uuid.create ()
    ; parent= None
    ; account_tbl= Location.Table.create ()
    ; hash_tbl= Addr.Table.create ()
    ; location_tbl= Key.Table.create ()
    ; current_location= None }

  let with_ledger ~f =
    let mask = create () in
    f mask

  module Attached = struct
    type parent = Base.t [@@deriving sexp]

    type t = unattached [@@deriving sexp]

    module Path = Base.Path
    module Addr = Location.Addr
    module Location = Location

    type index = int

    type path = Path.t

    type root_hash = Hash.t

    exception Location_is_not_account of Location.t

    let create () =
      failwith
        "Mask.Attached.create: cannot create an attached mask; use \
         Mask.create and Mask.set_parent"

    let with_ledger ~f:_ =
      failwith
        "Mask.Attached.with_ledger: cannot create an attached mask; use \
         Mask.create and Mask.set_parent"

    let unset_parent t =
      t.parent <- None ;
      t

    let get_parent {parent= opt; _} = Option.value_exn opt

    let get_uuid t = t.uuid

    (* don't rely on a particular implementation *)
    let find_hash t address = Addr.Table.find t.hash_tbl address

    let set_hash t address hash =
      Addr.Table.set t.hash_tbl ~key:address ~data:hash

    let set_inner_hash_at_addr_exn t address hash =
      assert (Addr.depth address <= Base.depth) ;
      set_hash t address hash

    (* don't rely on a particular implementation *)
    let find_location t public_key = Key.Table.find t.location_tbl public_key

    let set_location t public_key location =
      Key.Table.set t.location_tbl ~key:public_key ~data:location

    (* don't rely on a particular implementation *)
    let find_account t location = Location.Table.find t.account_tbl location

    let find_all_accounts t = Location.Table.data t.account_tbl

    let set_account t location account =
      Location.Table.set t.account_tbl ~key:location ~data:account ;
      set_location t (Account.public_key account) location

    (* a read does a lookup in the account_tbl; if that fails, delegate to parent *)
    let get t location =
      match find_account t location with
      | Some account -> Some account
      | None -> Base.get (get_parent t) location

    (* fixup_merkle_path patches a Merkle path reported by the parent, overriding
       with hashes which are stored in the mask
    *)

    let fixup_merkle_path t path address =
      let rec build_fixed_path path address accum =
        if List.is_empty path then List.rev accum
        else
          (* first element in the path contains hash at sibling of address *)
          let curr_element = List.hd_exn path in
          let merkle_node_address = Addr.sibling address in
          let mask_hash = find_hash t merkle_node_address in
          let parent_hash =
            match curr_element with `Left h | `Right h -> h
          in
          let new_hash = Option.value mask_hash ~default:parent_hash in
          let new_element =
            match curr_element with
            | `Left _ -> `Left new_hash
            | `Right _ -> `Right new_hash
          in
          build_fixed_path (List.tl_exn path) (Addr.parent_exn address)
            (new_element :: accum)
      in
      build_fixed_path path address []

    (* the following merkle_path_* functions report the Merkle path for the mask *)

    let merkle_path_at_addr_exn t address =
      let parent_merkle_path =
        Base.merkle_path_at_addr_exn (get_parent t) address
      in
      fixup_merkle_path t parent_merkle_path address

    let merkle_path_at_index_exn t index =
      let address = Addr.of_int_exn index in
      let parent_merkle_path =
        Base.merkle_path_at_addr_exn (get_parent t) address
      in
      fixup_merkle_path t parent_merkle_path address

    let merkle_path t location =
      let address = Location.to_path_exn location in
      let parent_merkle_path = Base.merkle_path (get_parent t) location in
      fixup_merkle_path t parent_merkle_path address

    (* given a Merkle path corresponding to a starting address, calculate addresses and hash
       for each node affected by the starting hash; that is, along the path from the
       account address to root
    *)
    let addresses_and_hashes_from_merkle_path_exn merkle_path starting_address
        starting_hash : (Addr.t * Hash.t) list =
      let get_addresses_hashes height accum node =
        let last_address, last_hash = List.hd_exn accum in
        let next_address = Addr.parent_exn last_address in
        let next_hash =
          match node with
          | `Left sibling_hash -> Hash.merge ~height last_hash sibling_hash
          | `Right sibling_hash -> Hash.merge ~height sibling_hash last_hash
        in
        (next_address, next_hash) :: accum
      in
      List.foldi merkle_path
        ~init:[(starting_address, starting_hash)]
        ~f:get_addresses_hashes

    (* use mask Merkle root, if it exists, else get from parent *)
    let merkle_root t =
      match find_hash t (Addr.root ()) with
      | Some hash -> hash
      | None -> Base.merkle_root (get_parent t)

    let remove_account_and_update_hashes t location =
      (* remove account and key from tables *)
      let account = Option.value_exn (find_account t location) in
      Location.Table.remove t.account_tbl location ;
      (* TODO : use stack database to save unused location, which can be
         used when allocating a location
      *)
      Key.Table.remove t.location_tbl (Account.public_key account) ;
      (* reuse location if possible *)
      Option.iter t.current_location ~f:(fun curr_loc ->
          if Location.equal location curr_loc then
            match Location.prev location with
            | Some prev_loc -> t.current_location <- Some prev_loc
            | None -> t.current_location <- None ) ;
      (* update hashes *)
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.empty_account in
      let merkle_path = merkle_path t location in
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          set_hash t addr hash )

    (* a write writes only to the mask, parent is not involved
       need to update both account and hash pieces of the mask
    *)
    let set t location account =
      set_account t location account ;
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.hash_account account in
      let merkle_path = merkle_path t location in
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          set_hash t addr hash )

    (* if the mask's parent sets an account, we can prune an entry in the mask if the account in the parent
       is the same in the mask
    *)
    let parent_set_notify t account =
      match find_location t (Account.public_key account) with
      | None -> ()
      | Some location -> (
        match find_account t location with
        | Some existing_account ->
            if
              Key.equal
                (Account.public_key account)
                (Account.public_key existing_account)
            then remove_account_and_update_hashes t location
        | None -> () )

    (* as for accounts, we see if we have it in the mask, else delegate to parent *)
    let get_hash t addr =
      match find_hash t addr with
      | Some hash -> Some hash
      | None -> (
        try
          let hash = Base.get_inner_hash_at_addr_exn (get_parent t) addr in
          Some hash
        with _ -> None )

    (* batch operations
       TODO: rely on availability of batch operations in Base for speed
    *)
    (* NB: rocksdb does not support batch reads; should we offer this? *)
    let get_batch_exn t locations =
      List.map locations ~f:(fun location -> get t location)

    (* TODO: maybe create a new hash table from the alist, then merge *)
    let set_batch t locations_and_accounts =
      List.iter locations_and_accounts ~f:(fun (location, account) ->
          set t location account )

    (* NB: rocksdb does not support batch reads; is this needed? *)
    let get_hash_batch_exn t addrs =
      List.map addrs ~f:(fun addr ->
          match find_hash t addr with
          | Some account -> Some account
          | None -> (
            try Some (Base.get_inner_hash_at_addr_exn (get_parent t) addr)
            with _ -> None ) )

    (* transfer state from mask to parent; flush local state *)
    let commit t =
      let account_data = Location.Table.to_alist t.account_tbl in
      Base.set_batch (get_parent t) account_data ;
      Location.Table.clear t.account_tbl ;
      Addr.Table.clear t.hash_tbl

    (* copy tables in t; use same parent *)
    let copy t =
      { uuid= Uuid.create ()
      ; parent= Some (get_parent t)
      ; account_tbl= Location.Table.copy t.account_tbl
      ; location_tbl= Key.Table.copy t.location_tbl
      ; hash_tbl= Addr.Table.copy t.hash_tbl
      ; current_location= t.current_location }

    let last_filled t =
      Option.value_map
        (Base.last_filled (get_parent t))
        ~default:t.current_location
        ~f:(fun parent_loc ->
          match t.current_location with
          | None -> Some parent_loc
          | Some our_loc -> Some (max parent_loc our_loc) )

    let get_all_accounts_rooted_at_exn t address =
      Option.value_map ~default:[] (last_filled t) ~f:(fun allocation_addr ->
          let first_addr, last_addr = Addr.Range.subtree_range address in
          Addr.Range.fold
            (first_addr, min last_addr (Location.to_path_exn allocation_addr))
            ~init:[]
            ~f:(fun bit_index acc ->
              let queried_account = get t @@ Location.Account bit_index in
              (queried_account |> Option.value_exn) :: acc ) )
      |> List.rev

    (* set accounts in mask *)
    let set_all_accounts_rooted_at_exn t address (accounts : Account.t list) =
      (* basically, the same code used for the database implementation *)
      let first_node, last_node = Addr.Range.subtree_range address in
      Addr.Range.fold (first_node, last_node) ~init:accounts
        ~f:(fun bit_index -> function
        | head :: tail ->
            set t (Location.Account bit_index) head ;
            tail
        | [] -> [] )
      |> ignore

    (* keys from this mask and all ancestors *)
    let keys t =
      let mask_keys =
        Location.Table.data t.account_tbl
        |> List.map ~f:Account.public_key
        |> Key.Set.of_list
      in
      let parent_keys = Base.keys (get_parent t) in
      Key.Set.union parent_keys mask_keys

    let num_accounts t = keys t |> Key.Set.length

    let location_of_key t key =
      let mask_result = find_location t key in
      match mask_result with
      | Some _ -> mask_result
      | None -> Base.location_of_key (get_parent t) key

    (* not needed for in-memory mask; in the database, it's currently a NOP *)
    let make_space_for t = Base.make_space_for (get_parent t)

    let get_inner_hash_at_addr_exn t address =
      assert (Addr.depth address <= Base.depth) ;
      get_hash t address |> Option.value_exn

    let remove_accounts_exn t keys =
      let rec loop keys parent_keys mask_locations =
        match keys with
        | [] -> (parent_keys, mask_locations)
        | key :: rest -> (
          match find_location t key with
          | None -> loop rest (key :: parent_keys) mask_locations
          | Some loc -> loop rest parent_keys (loc :: mask_locations) )
      in
      (* parent_keys not in mask, may be in parent
         mask_locations definitely in mask
      *)
      let parent_keys, mask_locations = loop keys [] [] in
      (* allow call to parent to raise an exception
         if raised, the parent hasn't removed any accounts,
          and we don't try to remove any accounts from mask *)
      Base.remove_accounts_exn (get_parent t) parent_keys ;
      (* removing accounts in parent succeeded, so proceed with removing accounts from mask
         we sort mask locations in reverse order, potentially allowing reuse of locations
      *)
      let rev_sorted_mask_locations =
        List.sort mask_locations ~compare:(fun loc1 loc2 ->
            let loc1 = Location.to_path_exn loc1 in
            let loc2 = Location.to_path_exn loc2 in
            Location.Addr.compare loc2 loc1 )
      in
      List.iter rev_sorted_mask_locations
        ~f:(remove_account_and_update_hashes t)

    (* Destroy intentionally does not commit before destroying
     * as sometimes this is desired behavior *)
    let close t =
      Location.Table.clear t.account_tbl ;
      Addr.Table.clear t.hash_tbl ;
      Key.Table.clear t.location_tbl

    let index_of_key_exn t key =
      let location = location_of_key t key |> Option.value_exn in
      let addr = Location.to_path_exn location in
      Addr.to_int addr

    let get_at_index_exn t index =
      let addr = Addr.of_int_exn index in
      get t (Location.Account addr) |> Option.value_exn

    let set_at_index_exn t index account =
      let addr = Addr.of_int_exn index in
      set t (Location.Account addr) account

    let to_list t =
      keys t |> Set.to_list
      |> List.map ~f:(fun key ->
             let location = location_of_key t key |> Option.value_exn in
             match location with
             | Account addr ->
                 (Addr.to_int addr, get t location |> Option.value_exn)
             | location -> raise (Location_is_not_account location) )
      |> List.sort ~compare:(fun (addr1, _) (addr2, _) ->
             Int.compare addr1 addr2 )
      |> List.map ~f:(fun (_, account) -> account)

    (* TODO *)
    let iteri _t ~f:_ = failwith "iteri not implemented on masks"

    let foldi_with_ignored_keys t ignored_keys ~init ~f =
      let locations_and_accounts = Location.Table.to_alist t.account_tbl in
      (* parent should ignore keys in this mask *)
      let mask_keys =
        List.map locations_and_accounts ~f:(fun (_loc, acct) ->
            Account.public_key acct )
      in
      let mask_ignored_keys = Key.Set.of_list mask_keys in
      let all_ignored_keys = Key.Set.union ignored_keys mask_ignored_keys in
      (* in parent, ignore any passed-in ignored keys and keys in mask *)
      let parent_result =
        Base.foldi_with_ignored_keys (get_parent t) all_ignored_keys ~init ~f
      in
      let f' accum (location, account) =
        (* for mask, ignore just passed-in ignored keys *)
        if Key.Set.mem ignored_keys (Account.public_key account) then accum
        else
          let address = Location.to_path_exn location in
          f address accum account
      in
      List.fold locations_and_accounts ~init:parent_result ~f:f'

    let foldi t ~init ~f = foldi_with_ignored_keys t Key.Set.empty ~init ~f

    (* we would want fold_until to combine results from the parent and the mask
       way (1): use the parent result as the init of the mask fold (or vice-versa)
         the parent result may be of different type than the mask fold init, so
         we get a less general type than the signature indicates, so compilation fails
       way (2): make the folds independent, but there's not a specified way to combine
         the results
       way (3): load parent accounts into an in-memory list, merge with mask accounts, then fold;
          this becomes intractable if the parent has a large number of entries
    *)
    let fold_until _t ~init:_ ~f:_ ~finish:_ =
      failwith "fold_until: not implemented"

    module For_testing = struct
      let location_in_mask t location =
        Option.is_some (find_account t location)

      let address_in_mask t addr = Option.is_some (find_hash t addr)

      let current_location t = t.current_location
    end

    (* leftmost location *)
    let first_location =
      Location.Account
        ( Addr.of_directions
        @@ List.init Base.depth ~f:(fun _ -> Direction.Left) )

    let loc_max a b =
      let a' = Location.to_path_exn a in
      let b' = Location.to_path_exn b in
      if Location.Addr.compare a' b' > 0 then a else b

    (* NB: updates the mutable current_location field in t *)
    let get_or_create_account t key account =
      match find_location t key with
      | None -> (
        (* not in mask, maybe in parent *)
        match Base.location_of_key (get_parent t) key with
        | Some location -> Ok (`Existed, location)
        | None -> (
            (* not in parent, create new location *)
            let maybe_location =
              match last_filled t with
              | None -> Some first_location
              | Some loc -> Location.next loc
            in
            match maybe_location with
            | None -> Or_error.error_string "Db_error.Out_of_leaves"
            | Some location ->
                set t location account ;
                set_location t key location ;
                t.current_location <- Some location ;
                Ok (`Added, location) ) )
      | Some location -> Ok (`Existed, location)

    let get_or_create_account_exn t key account =
      get_or_create_account t key account
      |> Result.map_error ~f:(fun err -> raise (Error.to_exn err))
      |> Result.ok_exn

    let sexp_of_location = Location.sexp_of_t

    let location_of_sexp = Location.t_of_sexp

    let depth = Base.depth
  end

  let set_parent t parent =
    t.parent <- Some parent ;
    t.current_location <- Attached.last_filled t ;
    t
end
