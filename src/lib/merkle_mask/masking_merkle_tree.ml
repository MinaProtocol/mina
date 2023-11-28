(* masking_merkle_tree.ml -- implements a mask in front of a Merkle tree; see
   RFC 0004 and docs/specs/merkle_tree.md *)

open Core

(* builds a Merkle tree mask; it's a Merkle tree, with some additional
   operations
*)
module Make (Inputs : Inputs_intf.S) = struct
  open Inputs

  type account = Account.t

  type hash = Hash.t

  type account_id = Account_id.t

  type account_id_set = Account_id.Set.t

  type location = Location.t

  module Location = Location
  module Addr = Location.Addr

  (** Invariant is that parent is None in unattached mask and `Some` in the
      attached one. We can capture this with a GADT but there's some annoying
      issues with bin_io to do so *)
  module Parent = struct
    type t = (Base.t, string (* Location where null was set *)) Result.t
    [@@deriving sexp]
  end

  module Detached_parent_signal = struct
    type t = unit Async.Ivar.t

    let sexp_of_t (_ : t) = Sexp.List []

    let t_of_sexp (_ : Sexp.t) : t = Async.Ivar.create ()
  end

  type t =
    { uuid : Uuid.Stable.V1.t
    ; account_tbl : Account.t Location_binable.Table.t
    ; token_owners : Account_id.t Token_id.Table.t
    ; mutable parent : Parent.t
    ; detached_parent_signal : Detached_parent_signal.t
    ; hash_tbl : Hash.t Addr.Table.t
    ; location_tbl : Location.t Account_id.Table.t
    ; mutable current_location : Location.t option
    ; depth : int
    }
  [@@deriving sexp]

  type unattached = t [@@deriving sexp]

  let create ~depth () =
    { uuid = Uuid_unix.create ()
    ; parent = Error __LOC__
    ; detached_parent_signal = Async.Ivar.create ()
    ; account_tbl = Location_binable.Table.create ()
    ; token_owners = Token_id.Table.create ()
    ; hash_tbl = Addr.Table.create ()
    ; location_tbl = Account_id.Table.create ()
    ; current_location = None
    ; depth
    }

  let get_uuid { uuid; _ } = uuid

  let depth t = t.depth

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

    exception
      Dangling_parent_reference of
        Uuid.t * (* Location where null was set*) string

    let create () =
      failwith
        "Mask.Attached.create: cannot create an attached mask; use Mask.create \
         and Mask.set_parent"

    let with_ledger ~f:_ =
      failwith
        "Mask.Attached.with_ledger: cannot create an attached mask; use \
         Mask.create and Mask.set_parent"

    let unset_parent ?(trigger_signal = true) ~loc t =
      assert (Result.is_ok t.parent) ;
      t.parent <- Error loc ;
      if trigger_signal then
        Async.Ivar.fill_if_empty t.detached_parent_signal () ;
      t

    let assert_is_attached t =
      match t.parent with
      | Error loc ->
          raise (Dangling_parent_reference (t.uuid, loc))
      | Ok _ ->
          ()

    let detached_signal t = Async.Ivar.read t.detached_parent_signal

    let get_parent ({ parent = opt; _ } as t) =
      assert_is_attached t ; Result.ok_or_failwith opt

    let get_uuid t = assert_is_attached t ; t.uuid

    let get_directory t =
      assert_is_attached t ;
      Base.get_directory (Result.ok_or_failwith t.parent)

    let depth t = assert_is_attached t ; t.depth

    (* don't rely on a particular implementation *)
    let self_find_hash t address =
      assert_is_attached t ;
      Addr.Table.find t.hash_tbl address

    let self_set_hash t address hash =
      assert_is_attached t ;
      Addr.Table.set t.hash_tbl ~key:address ~data:hash

    let set_inner_hash_at_addr_exn t address hash =
      assert_is_attached t ;
      assert (Addr.depth address <= t.depth) ;
      self_set_hash t address hash

    (* don't rely on a particular implementation *)
    let self_find_location t account_id =
      assert_is_attached t ;
      Account_id.Table.find t.location_tbl account_id

    let self_set_location t account_id location =
      assert_is_attached t ;
      Account_id.Table.set t.location_tbl ~key:account_id ~data:location ;
      (* if account is at a hitherto-unused location, that
         becomes the current location
      *)
      match t.current_location with
      | None ->
          t.current_location <- Some location
      | Some loc ->
          if Location.( > ) location loc then
            t.current_location <- Some location

    (* don't rely on a particular implementation *)
    let self_find_account t location =
      assert_is_attached t ;
      Location_binable.Table.find t.account_tbl location

    let self_set_account t location account =
      assert_is_attached t ;
      Location_binable.Table.set t.account_tbl ~key:location ~data:account ;
      self_set_location t (Account.identifier account) location

    (* a read does a lookup in the account_tbl; if that fails, delegate to
       parent *)
    let get t location =
      assert_is_attached t ;
      match self_find_account t location with
      | Some account ->
          Some account
      | None ->
          let is_empty =
            match t.current_location with
            | None ->
                true
            | Some current_location ->
                let address = Location.to_path_exn location in
                let current_address = Location.to_path_exn current_location in
                Addr.is_further_right ~than:current_address address
          in
          if is_empty then None else Base.get (get_parent t) location

    let self_find_or_batch_lookup self_find lookup_parent t ids =
      assert_is_attached t ;
      let self_found_or_none = List.map ids ~f:self_find in
      let not_found =
        List.filter_map self_found_or_none ~f:(function
          | id, None ->
              Some id
          | _ ->
              None )
      in
      let from_parent = lookup_parent (get_parent t) not_found in
      List.fold_map self_found_or_none ~init:from_parent
        ~f:(fun from_parent (id, self_found) ->
          match (self_found, from_parent) with
          | None, r :: rest ->
              (rest, r)
          | Some acc_found_locally, _ ->
              (from_parent, (id, acc_found_locally))
          | _ ->
              failwith "unexpected number of results from DB" )
      |> snd

    let get_batch t =
      let self_find id =
        let res = self_find_account t id in
        let res =
          if Option.is_none res then
            let is_empty =
              Option.value_map ~default:true t.current_location
                ~f:(fun current_location ->
                  let address = Location.to_path_exn id in
                  let current_address = Location.to_path_exn current_location in
                  Addr.is_further_right ~than:current_address address )
            in
            Option.some_if is_empty None
          else Some res
        in
        (id, res)
      in
      self_find_or_batch_lookup self_find Base.get_batch t

    let empty_hash =
      Empty_hashes.extensible_cache (module Hash) ~init_hash:Hash.empty_account

    let self_path_get_hash ~hashes ~current_location height address =
      match Hashtbl.find hashes address with
      | Some hash ->
          Some hash
      | None ->
          let is_empty =
            match current_location with
            | None ->
                true
            | Some current_location ->
                let current_address = Location.to_path_exn current_location in
                Addr.is_further_right ~than:current_address address
          in
          if is_empty then Some (empty_hash height) else None

    let rec self_path_impl ~element ~depth address =
      let height = Addr.height ~ledger_depth:depth address in
      if height >= depth then Some []
      else
        let%bind.Option el = element height address in
        let%bind.Option parent_address = Addr.parent address |> Or_error.ok in
        let%map.Option rest = self_path_impl ~element ~depth parent_address in
        el :: rest

    let self_merkle_path ~hashes ~current_location =
      let element height address =
        let sibling = Addr.sibling address in
        let sibling_dir = Location.last_direction address in
        let%map.Option sibling_hash =
          self_path_get_hash ~hashes ~current_location height sibling
        in
        Direction.map sibling_dir ~left:(`Left sibling_hash) ~right:(`Right sibling_hash)
      in
      self_path_impl ~element

    let self_wide_merkle_path ~hashes ~current_location =
      let element height address =
        let sibling = Addr.sibling address in
        let sibling_dir = Location.last_direction address in
        let%bind.Option sibling_hash =
          self_path_get_hash ~hashes ~current_location height sibling
        in
        let%map.Option self_hash =
          self_path_get_hash ~hashes ~current_location height address
        in
        Direction.map sibling_dir
          ~left:(`Left (self_hash, sibling_hash))
          ~right:(`Right (sibling_hash, self_hash))
      in
      self_path_impl ~element

    (* fixup_merkle_path patches a Merkle path reported by the parent,
       overriding with hashes which are stored in the mask *)
    let fixup_merkle_path ~hashes ~address:init =
      let f address =
        (* first element in the path contains hash at sibling of address *)
        let sibling_mask_hash = Hashtbl.find hashes (Addr.sibling address) in
        let parent_addr = Addr.parent_exn address in
        let open Option in
        function
        | `Left h ->
            (parent_addr, `Left (value sibling_mask_hash ~default:h))
        | `Right h ->
            (parent_addr, `Right (value sibling_mask_hash ~default:h))
      in
      Fn.compose snd @@ List.fold_map ~init ~f

    (* fixup_merkle_path patches a Merkle path reported by the parent,
       overriding with hashes which are stored in the mask *)
    let fixup_wide_merkle_path ~hashes ~address:init =
      let f address =
        (* element in the path contains hash at sibling of address *)
        let sibling_mask_hash = Hashtbl.find hashes (Addr.sibling address) in
        let self_mask_hash = Hashtbl.find hashes address in
        let parent_addr = Addr.parent_exn address in
        let open Option in
        function
        | `Left (h_l, h_r) ->
            ( parent_addr
            , `Left
                ( value self_mask_hash ~default:h_l
                , value sibling_mask_hash ~default:h_r ) )
        | `Right (h_l, h_r) ->
            ( parent_addr
            , `Right
                ( value sibling_mask_hash ~default:h_l
                , value self_mask_hash ~default:h_r ) )
      in
      Fn.compose snd @@ List.fold_map ~init ~f

    (* the following merkle_path_* functions report the Merkle path for the
       mask *)

    let merkle_path_at_addr_exn t address =
      assert_is_attached t ;
      match
        self_merkle_path ~depth:t.depth ~hashes:t.hash_tbl
          ~current_location:t.current_location address
      with
      | Some path ->
          path
      | None ->
          let parent_merkle_path =
            Base.merkle_path_at_addr_exn (get_parent t) address
          in
          fixup_merkle_path ~hashes:t.hash_tbl parent_merkle_path ~address

    let merkle_path_at_index_exn t index =
      merkle_path_at_addr_exn t (Addr.of_int_exn ~ledger_depth:t.depth index)

    let merkle_path t location =
      merkle_path_at_addr_exn t (Location.to_path_exn location)

    let path_batch_impl ~fixup_path ~self_lookup ~base_lookup t locations =
      assert_is_attached t ;
      let parent = get_parent t in
      let self_paths =
        List.map locations ~f:(fun location ->
            let address = Location.to_path_exn location in
            self_lookup ~hashes:t.hash_tbl ~current_location:t.current_location
              ~depth:t.depth address
            |> Option.value_map
                 ~default:(Either.Second (location, address))
                 ~f:Either.first )
      in
      let all_parent_paths =
        let locs =
          List.filter_map self_paths ~f:(function
            | Either.First _ ->
                None
            | Either.Second (location, _) ->
                Some location )
        in
        if List.is_empty locs then [] else base_lookup parent locs
      in
      let f parent_paths = function
        | Either.First path ->
            (parent_paths, path)
        | Either.Second (_, address) ->
            let path =
              fixup_path ~hashes:t.hash_tbl ~address (List.hd_exn parent_paths)
            in
            (List.tl_exn parent_paths, path)
      in
      snd @@ List.fold_map ~init:all_parent_paths ~f self_paths

    let merkle_path_batch =
      path_batch_impl ~base_lookup:Base.merkle_path_batch
        ~self_lookup:self_merkle_path ~fixup_path:fixup_merkle_path

    let wide_merkle_path_batch =
      path_batch_impl ~base_lookup:Base.wide_merkle_path_batch
        ~self_lookup:self_wide_merkle_path ~fixup_path:fixup_wide_merkle_path

    (* given a Merkle path corresponding to a starting address, calculate
       addresses and hashes for each node affected by the starting hash; that is,
       along the path from the account address to root *)
    let addresses_and_hashes_from_merkle_path_exn merkle_path starting_address
        starting_hash : (Addr.t * Hash.t) list =
      let get_addresses_hashes height accum node =
        let last_address, last_hash = List.hd_exn accum in
        let next_address = Addr.parent_exn last_address in
        let next_hash =
          match node with
          | `Left sibling_hash ->
              Hash.merge ~height last_hash sibling_hash
          | `Right sibling_hash ->
              Hash.merge ~height sibling_hash last_hash
        in
        (next_address, next_hash) :: accum
      in
      List.foldi merkle_path
        ~init:[ (starting_address, starting_hash) ]
        ~f:get_addresses_hashes

    (* use mask Merkle root, if it exists, else get from parent *)
    let merkle_root t =
      assert_is_attached t ;
      match self_find_hash t (Addr.root ()) with
      | Some hash ->
          hash
      | None ->
          Base.merkle_root (get_parent t)

    let remove_account_and_update_hashes t location =
      assert_is_attached t ;
      (* remove account and key from tables *)
      let account = Option.value_exn (self_find_account t location) in
      Location_binable.Table.remove t.account_tbl location ;
      (* Update token info. *)
      let account_id = Account.identifier account in
      Token_id.Table.remove t.token_owners
        (Account_id.derive_token_id ~owner:account_id) ;
      (* TODO : use stack database to save unused location, which can be used
         when allocating a location *)
      Account_id.Table.remove t.location_tbl account_id ;
      (* reuse location if possible *)
      Option.iter t.current_location ~f:(fun curr_loc ->
          if Location.equal location curr_loc then
            match Location.prev location with
            | Some prev_loc ->
                t.current_location <- Some prev_loc
            | None ->
                t.current_location <- None ) ;
      (* update hashes *)
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.empty_account in
      let merkle_path = merkle_path t location in
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          self_set_hash t addr hash )

    let set_account_unsafe t location account =
      assert_is_attached t ;
      self_set_account t location account ;
      (* Update token info. *)
      let account_id = Account.identifier account in
      Token_id.Table.set t.token_owners
        ~key:(Account_id.derive_token_id ~owner:account_id)
        ~data:account_id

    (* a write writes only to the mask, parent is not involved need to update
       both account and hash pieces of the mask *)
    let set t location account =
      assert_is_attached t ;
      set_account_unsafe t location account ;
      (* Update merkle path. *)
      let account_address = Location.to_path_exn location in
      let account_hash = Hash.hash_account account in
      let merkle_path = merkle_path t location in
      let addresses_and_hashes =
        addresses_and_hashes_from_merkle_path_exn merkle_path account_address
          account_hash
      in
      List.iter addresses_and_hashes ~f:(fun (addr, hash) ->
          self_set_hash t addr hash )

    (* if the mask's parent sets an account, we can prune an entry in the mask
       if the account in the parent is the same in the mask *)
    let parent_set_notify t account =
      assert_is_attached t ;
      match self_find_location t (Account.identifier account) with
      | None ->
          ()
      | Some location -> (
          match self_find_account t location with
          | Some existing_account ->
              if Account.equal account existing_account then
                remove_account_and_update_hashes t location
          | None ->
              () )

    (* as for accounts, we see if we have it in the mask, else delegate to
       parent *)
    let get_hash t addr =
      assert_is_attached t ;
      match self_find_hash t addr with
      | Some hash ->
          Some hash
      | None -> (
          try
            let hash = Base.get_inner_hash_at_addr_exn (get_parent t) addr in
            Some hash
          with _ -> None )

    (* batch operations TODO: rely on availability of batch operations in Base
       for speed *)
    (* NB: rocksdb does not support batch reads; should we offer this? *)
    let get_batch_exn t locations =
      assert_is_attached t ;
      List.map locations ~f:(fun location -> get t location)

    let get_hash_batch_exn t locations =
      assert_is_attached t ;
      let self_hashes_rev =
        List.rev_map locations ~f:(fun location ->
            (location, self_find_hash t (Location.to_path_exn location)) )
      in
      let parent_locations_rev =
        List.filter_map self_hashes_rev ~f:(fun (location, hash) ->
            match hash with None -> Some location | Some _ -> None )
      in
      let parent_hashes_rev =
        if List.is_empty parent_locations_rev then []
        else Base.get_hash_batch_exn (get_parent t) parent_locations_rev
      in
      let rec recombine self_hashes_rev parent_hashes_rev acc =
        match (self_hashes_rev, parent_hashes_rev) with
        | [], [] ->
            acc
        | (_location, None) :: self_hashes_rev, hash :: parent_hashes_rev
        | (_location, Some hash) :: self_hashes_rev, parent_hashes_rev ->
            recombine self_hashes_rev parent_hashes_rev (hash :: acc)
        | _, [] | [], _ ->
            assert false
      in
      recombine self_hashes_rev parent_hashes_rev []

    (* transfer state from mask to parent; flush local state *)
    let commit t =
      assert_is_attached t ;
      let old_root_hash = merkle_root t in
      let account_data = Location_binable.Table.to_alist t.account_tbl in
      Base.set_batch (get_parent t) account_data ;
      Location_binable.Table.clear t.account_tbl ;
      Addr.Table.clear t.hash_tbl ;
      Debug_assert.debug_assert (fun () ->
          [%test_result: Hash.t]
            ~message:
              "Parent merkle root after committing should be the same as the \
               old one in the mask"
            ~expect:old_root_hash
            (Base.merkle_root (get_parent t)) ;
          [%test_result: Hash.t]
            ~message:"Merkle root of the mask should delegate to the parent now"
            ~expect:(merkle_root t)
            (Base.merkle_root (get_parent t)) )

    (* copy tables in t; use same parent *)
    let copy t =
      { uuid = Uuid_unix.create ()
      ; parent = Ok (get_parent t)
      ; detached_parent_signal = Async.Ivar.create ()
      ; account_tbl = Location_binable.Table.copy t.account_tbl
      ; token_owners = Token_id.Table.copy t.token_owners
      ; location_tbl = Account_id.Table.copy t.location_tbl
      ; hash_tbl = Addr.Table.copy t.hash_tbl
      ; current_location = t.current_location
      ; depth = t.depth
      }

    let last_filled t =
      assert_is_attached t ;
      Option.value_map
        (Base.last_filled (get_parent t))
        ~default:t.current_location
        ~f:(fun parent_loc ->
          match t.current_location with
          | None ->
              Some parent_loc
          | Some our_loc -> (
              match (parent_loc, our_loc) with
              | Account parent_addr, Account our_addr ->
                  (* Addr.compare is Bitstring.compare, essentially String.compare *)
                  let loc =
                    if Addr.compare parent_addr our_addr >= 0 then parent_loc
                    else our_loc
                  in
                  Some loc
              | _ ->
                  failwith
                    "last_filled: expected account locations for the parent \
                     and mask" ) )

    include Merkle_ledger.Util.Make (struct
      module Location = Location
      module Location_binable = Location_binable
      module Key = Key
      module Token_id = Token_id
      module Account_id = Account_id
      module Account = Account
      module Hash = Hash
      module Balance = Balance

      module Base = struct
        type nonrec t = t

        let get = get

        let last_filled = last_filled
      end

      let ledger_depth = depth

      let location_of_account_addr addr = Location.Account addr

      let location_of_hash_addr addr = Location.Hash addr

      let get_hash t location =
        Option.value_exn (get_hash t (Location.to_path_exn location))

      let set_raw_hash_batch t locations_and_hashes =
        List.iter locations_and_hashes ~f:(fun (location, hash) ->
            self_set_hash t (Location.to_path_exn location) hash )

      let set_location_batch ~last_location t account_to_location_list =
        t.current_location <- Some last_location ;
        Mina_stdlib.Nonempty_list.iter account_to_location_list
          ~f:(fun (key, data) ->
            Account_id.Table.set t.location_tbl ~key ~data )

      let set_raw_account_batch t locations_and_accounts =
        List.iter locations_and_accounts ~f:(fun (location, account) ->
            let account_id = Account.identifier account in
            Token_id.Table.set t.token_owners
              ~key:(Account_id.derive_token_id ~owner:account_id)
              ~data:account_id ;
            self_set_account t location account )
    end)

    let set_batch_accounts t addresses_and_accounts =
      assert_is_attached t ;
      set_batch_accounts t addresses_and_accounts

    (* set accounts in mask *)
    let set_all_accounts_rooted_at_exn t address (accounts : Account.t list) =
      assert_is_attached t ;
      set_all_accounts_rooted_at_exn t address accounts

    let token_owner t tid =
      assert_is_attached t ;
      match Token_id.Table.find t.token_owners tid with
      | Some id ->
          Some id
      | None ->
          Base.token_owner (get_parent t) tid

    let token_owners (t : t) : Account_id.Set.t =
      assert_is_attached t ;
      let mask_owners =
        Hashtbl.fold t.token_owners ~init:Account_id.Set.empty
          ~f:(fun ~key:_tid ~data:owner acc -> Set.add acc owner)
      in
      Set.union mask_owners (Base.token_owners (get_parent t))

    let tokens t pk =
      assert_is_attached t ;
      let mask_tokens =
        Account_id.Table.keys t.location_tbl
        |> List.filter_map ~f:(fun aid ->
               if Key.equal pk (Account_id.public_key aid) then
                 Some (Account_id.token_id aid)
               else None )
        |> Token_id.Set.of_list
      in
      Set.union mask_tokens (Base.tokens (get_parent t) pk)

    let num_accounts t =
      assert_is_attached t ;
      match t.current_location with
      | None ->
          0
      | Some location -> (
          match location with
          | Account addr ->
              Addr.to_int addr + 1
          | _ ->
              failwith "Expected mask current location to represent an account"
          )

    let location_of_account t account_id =
      assert_is_attached t ;
      let mask_result = self_find_location t account_id in
      match mask_result with
      | Some _ ->
          mask_result
      | None ->
          Base.location_of_account (get_parent t) account_id

    let location_of_account_batch t =
      self_find_or_batch_lookup
        (fun id -> (id, Option.map ~f:Option.some @@ self_find_location t id))
        Base.location_of_account_batch t

    (* Adds specified accounts to the mask by laoding them from parent ledger.

       Could be useful for transaction processing when to pre-populate mask with the
       accounts used in processing a transaction (or a block) to ensure there are not loaded
       from parent on each lookup. I.e. these accounts will be cached in mask and accessing
       them during processing of a transaction won't use disk I/O.
    *)
    let unsafe_preload_accounts_from_parent t account_ids =
      assert_is_attached t ;
      let locations = location_of_account_batch t account_ids in
      let non_empty_locations = List.filter_map locations ~f:snd in
      let accounts = get_batch t non_empty_locations in
      let all_hash_locations =
        let rec generate_locations account_locations acc =
          match account_locations with
          | [] ->
              acc
          | location :: account_locations -> (
              let address = Location.to_path_exn location in
              match Addr.parent address with
              | Ok parent ->
                  let sibling = Addr.sibling address in
                  generate_locations
                    (Location.Hash parent :: account_locations)
                    (Location.Hash address :: Location.Hash sibling :: acc)
              | Error _ ->
                  (* This is the root. It's somewhat wasteful to add it for
                     every account, but makes this logic simpler.
                  *)
                  generate_locations account_locations
                    (Location.Hash address :: acc) )
        in
        generate_locations non_empty_locations []
      in
      let all_hashes =
        Base.get_hash_batch_exn (get_parent t) all_hash_locations
      in
      (* Batch import merkle paths and self hashes. *)
      List.iter2_exn all_hash_locations all_hashes ~f:(fun location hash ->
          let address = Location.to_path_exn location in
          self_set_hash t address hash ) ;
      (* Batch import accounts. *)
      List.iter accounts ~f:(fun (location, account) ->
          match account with
          | None ->
              ()
          | Some account ->
              set_account_unsafe t location account )

    (* not needed for in-memory mask; in the database, it's currently a NOP *)
    let make_space_for t =
      assert_is_attached t ;
      Base.make_space_for (get_parent t)

    let get_inner_hash_at_addr_exn t address =
      assert_is_attached t ;
      assert (Addr.depth address <= t.depth) ;
      get_hash t address |> Option.value_exn

    let remove_accounts_exn t keys =
      assert_is_attached t ;
      let rec loop keys parent_keys mask_locations =
        match keys with
        | [] ->
            (parent_keys, mask_locations)
        | key :: rest -> (
            match self_find_location t key with
            | None ->
                loop rest (key :: parent_keys) mask_locations
            | Some loc ->
                loop rest parent_keys (loc :: mask_locations) )
      in
      (* parent_keys not in mask, may be in parent mask_locations definitely in
         mask *)
      let parent_keys, mask_locations = loop keys [] [] in
      (* allow call to parent to raise an exception if raised, the parent
         hasn't removed any accounts, and we don't try to remove any accounts
         from mask *)
      Base.remove_accounts_exn (get_parent t) parent_keys ;
      (* removing accounts in parent succeeded, so proceed with removing
         accounts from mask we sort mask locations in reverse order,
         potentially allowing reuse of locations *)
      let rev_sorted_mask_locations =
        List.sort mask_locations ~compare:(fun loc1 loc2 ->
            let loc1 = Location.to_path_exn loc1 in
            let loc2 = Location.to_path_exn loc2 in
            Location.Addr.compare loc2 loc1 )
      in
      List.iter rev_sorted_mask_locations
        ~f:(remove_account_and_update_hashes t)

    (* Destroy intentionally does not commit before destroying
       as sometimes this is desired behavior *)
    let close t =
      assert_is_attached t ;
      Location_binable.Table.clear t.account_tbl ;
      Addr.Table.clear t.hash_tbl ;
      Account_id.Table.clear t.location_tbl ;
      Async.Ivar.fill_if_empty t.detached_parent_signal ()

    let index_of_account_exn t key =
      assert_is_attached t ;
      let location = location_of_account t key |> Option.value_exn in
      let addr = Location.to_path_exn location in
      Addr.to_int addr

    let get_at_index_exn t index =
      assert_is_attached t ;
      let addr = Addr.of_int_exn ~ledger_depth:t.depth index in
      get t (Location.Account addr) |> Option.value_exn

    let set_at_index_exn t index account =
      assert_is_attached t ;
      let addr = Addr.of_int_exn ~ledger_depth:t.depth index in
      set t (Location.Account addr) account

    let to_list t =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      Async.Deferred.List.init ~how:`Parallel num_accounts ~f:(fun i ->
          Async.Deferred.return @@ get_at_index_exn t i )

    let to_list_sequential t =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      List.init num_accounts ~f:(fun i -> get_at_index_exn t i)

    (* keys from this mask and all ancestors *)
    let accounts t =
      assert_is_attached t ;
      let%map.Async.Deferred accts = to_list t in
      List.map accts ~f:Account.identifier |> Account_id.Set.of_list

    let iteri t ~f =
      assert_is_attached t ;
      let num_accounts = num_accounts t in
      Sequence.range ~stop:`exclusive 0 num_accounts
      |> Sequence.iter ~f:(fun i -> f i (get_at_index_exn t i))

    let foldi_with_ignored_accounts t ignored_accounts ~init ~f =
      assert_is_attached t ;
      let locations_and_accounts =
        Location_binable.Table.to_alist t.account_tbl
      in
      (* parent should ignore accounts in this mask *)
      let mask_accounts =
        List.map locations_and_accounts ~f:(fun (_loc, acct) ->
            Account.identifier acct )
      in
      let mask_ignored_accounts = Account_id.Set.of_list mask_accounts in
      let all_ignored_accounts =
        Account_id.Set.union ignored_accounts mask_ignored_accounts
      in
      (* in parent, ignore any passed-in ignored accounts and accounts in mask *)
      let parent_result =
        Base.foldi_with_ignored_accounts (get_parent t) all_ignored_accounts
          ~init ~f
      in
      let f' accum (location, account) =
        (* for mask, ignore just passed-in ignored accounts *)
        if Account_id.Set.mem ignored_accounts (Account.identifier account) then
          accum
        else
          let address = Location.to_path_exn location in
          f address accum account
      in
      List.fold locations_and_accounts ~init:parent_result ~f:f'

    let foldi t ~init ~f =
      assert_is_attached t ;
      foldi_with_ignored_accounts t Account_id.Set.empty ~init ~f

    (* we would want fold_until to combine results from the parent and the mask
       way (1): use the parent result as the init of the mask fold (or
         vice-versa) the parent result may be of different type than the mask
         fold init, so we get a less general type than the signature indicates,
         so compilation fails
       way (2): make the folds independent, but there's not a specified way to
         combine the results
       way (3): load parent accounts into an in-memory list, merge with mask
         accounts, then fold; this becomes intractable if the parent has a large
         number of entries *)
    let fold_until _t ~init:_ ~f:_ ~finish:_ =
      failwith "fold_until: not implemented"

    module For_testing = struct
      let location_in_mask t location =
        Option.is_some (self_find_account t location)

      let address_in_mask t addr = Option.is_some (self_find_hash t addr)

      let current_location t = t.current_location
    end

    (* leftmost location *)
    let first_location ~ledger_depth =
      Location.Account
        ( Addr.of_directions
        @@ List.init ledger_depth ~f:(fun _ -> Direction.Left) )

    let loc_max a b =
      let a' = Location.to_path_exn a in
      let b' = Location.to_path_exn b in
      if Location.Addr.compare a' b' > 0 then a else b

    (* NB: updates the mutable current_location field in t *)
    let get_or_create_account t account_id account =
      assert_is_attached t ;
      match self_find_location t account_id with
      | None -> (
          (* not in mask, maybe in parent *)
          match Base.location_of_account (get_parent t) account_id with
          | Some location ->
              Ok (`Existed, location)
          | None -> (
              (* not in parent, create new location *)
              let maybe_location =
                match last_filled t with
                | None ->
                    Some (first_location ~ledger_depth:t.depth)
                | Some loc ->
                    Location.next loc
              in
              match maybe_location with
              | None ->
                  Or_error.error_string "Db_error.Out_of_leaves"
              | Some location ->
                  (* `set` calls `self_set_location`, which updates
                     the current location
                  *)
                  set t location account ;
                  Ok (`Added, location) ) )
      | Some location ->
          Ok (`Existed, location)

    let sexp_of_location = Location.sexp_of_t

    let location_of_sexp = Location.t_of_sexp
  end

  let set_parent t parent =
    assert (Result.is_error t.parent) ;
    assert (Option.is_none (Async.Ivar.peek t.detached_parent_signal)) ;
    assert (Int.equal t.depth (Base.depth parent)) ;
    t.parent <- Ok parent ;
    t.current_location <- Attached.last_filled t ;
    t

  let addr_to_location addr = Location.Account addr
end
