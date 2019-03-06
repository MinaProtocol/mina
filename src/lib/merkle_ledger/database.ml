open Core

module Make
    (Key : Intf.Key)
    (Account : Intf.Account with type key := Key.t)
    (Hash : Intf.Hash with type account := Account.t)
    (Depth : Intf.Depth)
    (Location : Location_intf.S)
    (Kvdb : Intf.Key_value_database)
    (Storage_locations : Intf.Storage_locations) :
  Database_intf.S
  with module Location = Location
   and module Addr = Location.Addr
   and type account := Account.t
   and type root_hash := Hash.t
   and type hash := Hash.t
   and type key := Key.t
   and type key_set := Key.Set.t = struct
  (* The max depth of a merkle tree can never be greater than 253. *)
  include Depth

  let () = assert (Depth.depth < 0xfe)

  module Db_error = struct
    type t = Account_location_not_found | Out_of_leaves | Malformed_database
    [@@deriving sexp]

    exception Db_exception of t
  end

  module Path = Merkle_path.Make (Hash)
  module Addr = Location.Addr
  module Location = Location
  module Key = Key

  type location = Location.t [@@deriving sexp]

  type index = int

  type path = Path.t

  type t = {uuid: Uuid.Stable.V1.t; kvdb: Kvdb.t sexp_opaque} [@@deriving sexp]

  let get_uuid t = t.uuid

  let create ?directory_name () =
    let uuid = Uuid.create () in
    let directory =
      match directory_name with
      | None -> Uuid.to_string uuid
      | Some name -> name
    in
    let kvdb = Kvdb.create ~directory in
    {uuid; kvdb}

  let close {uuid= _; kvdb} = Kvdb.close kvdb

  let with_ledger ~f =
    let t = create () in
    try
      let result = f t in
      close t ; result
    with exn -> close t ; raise exn

  let empty_hashes =
    Empty_hashes.cache (module Hash) ~init_hash:Hash.empty_account Depth.depth

  let get_raw {kvdb; _} location =
    Kvdb.get kvdb ~key:(Location.serialize location)

  let get_bin mdb location bin_read =
    get_raw mdb location |> Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0))

  let delete_raw {kvdb; _} location =
    Kvdb.remove kvdb ~key:(Location.serialize location)

  let get mdb location =
    assert (Location.is_account location) ;
    get_bin mdb location Account.bin_read_t

  let get_hash mdb location =
    assert (Location.is_hash location) ;
    match get_bin mdb location Hash.bin_read_t with
    | Some hash -> hash
    | None -> Immutable_array.get empty_hashes (Location.height location)

  let account_list_bin {kvdb; _} account_bin_read : Account.t list =
    let all_keys_values = Kvdb.to_alist kvdb in
    (* see comment at top of location.ml about encoding of locations *)
    let account_location_prefix =
      Location.Prefix.account |> Unsigned.UInt8.to_int
    in
    (* just want list of locations and accounts, ignoring other locations *)
    let locations_accounts_bin =
      List.filter all_keys_values ~f:(fun (loc, _v) ->
          let ch = Bigstring.get_uint8 loc ~pos:0 in
          Int.equal ch account_location_prefix )
    in
    List.map locations_accounts_bin ~f:(fun (_location_bin, account_bin) ->
        account_bin_read account_bin ~pos_ref:(ref 0) )

  let to_list mdb = account_list_bin mdb Account.bin_read_t

  let keys mdb =
    to_list mdb |> List.map ~f:Account.public_key |> Key.Set.of_list

  let set_raw {kvdb; _} location bin =
    Kvdb.set kvdb ~key:(Location.serialize location) ~data:bin

  let set_raw_batch {kvdb; _} locations_bins =
    let serialize_location (loc, bin) = (Location.serialize loc, bin) in
    let serialized = List.map locations_bins ~f:serialize_location in
    Kvdb.set_batch kvdb ~key_data_pairs:serialized

  let set_bin mdb location bin_size bin_write v =
    let buf = Bigstring.create (bin_size v) in
    ignore (bin_write buf ~pos:0 v) ;
    set_raw mdb location buf

  let set_bin_batch mdb bin_size bin_write locations_vs =
    let create_buf (loc, v) =
      let buf = Bigstring.create (bin_size v) in
      ignore (bin_write buf ~pos:0 v) ;
      (loc, buf)
    in
    let locs_bufs = List.map locations_vs ~f:create_buf in
    set_raw_batch mdb locs_bufs

  let get_inner_hash_at_addr_exn mdb address =
    assert (Addr.depth address <= Depth.depth) ;
    get_hash mdb (Location.Hash address)

  let set_inner_hash_at_addr_exn mdb address hash =
    assert (Addr.depth address <= Depth.depth) ;
    set_bin mdb (Location.Hash address) Hash.bin_size_t Hash.bin_write_t hash

  let make_space_for _t _tot = ()

  module Account_location = struct
    let get_generic mdb location =
      assert (Location.is_generic location) ;
      get_raw mdb location

    (* encodes a key as a location used as a database key, so we can find the
       account location associated with that key *)
    let build_location key =
      Location.build_generic
        (Bigstring.of_string ("$" ^ Format.sprintf !"%{sexp: Key.t}" key))

    let get mdb key =
      match get_generic mdb (build_location key) with
      | None -> Error Db_error.Account_location_not_found
      | Some location_bin ->
          let result =
            Location.parse location_bin
            |> Result.map_error ~f:(fun () -> Db_error.Malformed_database)
          in
          result

    let delete mdb key = delete_raw mdb (build_location key)

    let set mdb key location =
      set_raw mdb (build_location key) (Location.serialize location)

    let set_batch mdb keys_to_locations =
      let serialize_location (key, location) =
        (Location.serialize @@ key, Location.serialize location)
      in
      let serialized = List.map keys_to_locations ~f:serialize_location in
      Kvdb.set_batch mdb.kvdb ~key_data_pairs:serialized

    let last_location_key () =
      Location.build_generic (Bigstring.of_string "last_account_location")

    let increment_last_account_location mdb =
      let location = last_location_key () in
      match get_generic mdb location with
      | None ->
          let first_location =
            Location.Account
              ( Addr.of_directions
              @@ List.init Depth.depth ~f:(fun _ -> Direction.Left) )
          in
          set_raw mdb location (Location.serialize first_location) ;
          Result.return first_location
      | Some prev_location -> (
        match Location.parse prev_location with
        | Error () -> Error Db_error.Malformed_database
        | Ok prev_account_location ->
            Location.next prev_account_location
            |> Result.of_option ~error:Db_error.Out_of_leaves
            |> Result.map ~f:(fun next_account_location ->
                   set_raw mdb location
                     (Location.serialize next_account_location) ;
                   next_account_location ) )

    let allocate mdb key =
      let location_result = increment_last_account_location mdb in
      Result.map location_result ~f:(fun location ->
          set mdb key location ; location )

    let last_location_address mdb =
      match
        last_location_key () |> get_raw mdb |> Result.of_option ~error:()
        |> Result.bind ~f:Location.parse
      with
      | Error () -> None
      | Ok parsed_location -> Some (Location.to_path_exn parsed_location)

    let last_location mdb =
      match
        last_location_key () |> get_raw mdb |> Result.of_option ~error:()
        |> Result.bind ~f:Location.parse
      with
      | Error () -> None
      | Ok parsed_location -> Some parsed_location
  end

  let location_of_key t key =
    match Account_location.get t key with
    | Error _ -> None
    | Ok location -> Some location

  let last_filled t = Account_location.last_location t

  include Util.Make (struct
    module Key = Key
    module Location = Location
    module Account = Account
    module Hash = Hash
    module Depth = Depth

    module Base = struct
      type nonrec t = t

      let get = get

      let last_filled = last_filled
    end

    let get_hash = get_hash

    let location_of_account_addr addr = Location.Account addr

    let location_of_hash_addr addr = Location.Hash addr

    let set_raw_hash_batch mdb addresses_and_hashes =
      set_bin_batch mdb Hash.bin_size_t Hash.bin_write_t addresses_and_hashes

    let set_location_batch ~last_location mdb key_to_location_list =
      let last_location_key_value =
        (Account_location.last_location_key (), last_location)
      in
      Account_location.set_batch mdb
        ( Non_empty_list.cons last_location_key_value
            (Non_empty_list.map key_to_location_list ~f:(fun (key, location) ->
                 (Account_location.build_location key, location) ))
        |> Non_empty_list.to_list )

    let set_raw_account_batch mdb
        (addresses_and_accounts : (location * Account.t) list) =
      set_bin_batch mdb Account.bin_size_t Account.bin_write_t
        addresses_and_accounts
  end)

  let set_hash mdb location new_hash = set_hash_batch mdb [(location, new_hash)]

  module For_tests = struct
    let gen_account_location =
      let open Quickcheck.Let_syntax in
      let build_account (path : Direction.t list) =
        assert (List.length path = Depth.depth) ;
        Location.Account (Addr.of_directions path)
      in
      let%map dirs =
        Quickcheck.Generator.list_with_length Depth.depth Direction.gen
      in
      build_account dirs
  end

  let set mdb location account =
    set_bin mdb location Account.bin_size_t Account.bin_write_t account ;
    set_hash mdb
      (Location.Hash (Location.to_path_exn location))
      (Hash.hash_account account)

  let index_of_key_exn mdb key =
    let location = location_of_key mdb key |> Option.value_exn in
    let addr = Location.to_path_exn location in
    Addr.to_int addr

  let get_at_index_exn mdb index =
    let addr = Addr.of_int_exn index in
    get mdb (Location.Account addr) |> Option.value_exn

  let set_at_index_exn mdb index account =
    let addr = Addr.of_int_exn index in
    set mdb (Location.Account addr) account

  let get_or_create_account mdb key account =
    match Account_location.get mdb key with
    | Error Account_location_not_found -> (
      match Account_location.allocate mdb key with
      | Ok location ->
          set mdb location account ;
          Ok (`Added, location)
      | Error err ->
          Error (Error.create "get_or_create_account" err Db_error.sexp_of_t) )
    | Error err ->
        Error (Error.create "get_or_create_account" err Db_error.sexp_of_t)
    | Ok location -> Ok (`Existed, location)

  let get_or_create_account_exn mdb key account =
    get_or_create_account mdb key account
    |> Result.map_error ~f:(fun err -> raise (Error.to_exn err))
    |> Result.ok_exn

  let num_accounts t =
    match Account_location.last_location_address t with
    | None -> 0
    | Some addr -> Addr.to_int addr + 1

  let iteri t ~f =
    match Account_location.last_location_address t with
    | None -> ()
    | Some last_addr ->
        Sequence.range ~stop:`inclusive 0 (Addr.to_int last_addr)
        |> Sequence.iter ~f:(fun i -> f i (get_at_index_exn t i))

  (* TODO : if key-value store supports iteration mechanism, like RocksDB,
     maybe use that here, instead of loading all accounts into memory See Issue
     #1191 *)
  let foldi_with_ignored_keys t ignored_keys ~init ~f =
    let f' index accum account = f (Addr.of_int_exn index) accum account in
    match Account_location.last_location_address t with
    | None -> init
    | Some last_addr ->
        let ignored_indices =
          Int.Set.map ignored_keys ~f:(fun key ->
              try index_of_key_exn t key with _ -> -1
              (* dummy index for keys not in database *) )
        in
        let last = Addr.to_int last_addr in
        Sequence.range ~stop:`inclusive 0 last
        (* filter out indices corresponding to ignored keys *)
        |> Sequence.filter ~f:(fun loc -> not (Int.Set.mem ignored_indices loc))
        |> Sequence.map ~f:(get_at_index_exn t)
        |> Sequence.foldi ~init ~f:f'

  let foldi t ~init ~f = foldi_with_ignored_keys t Key.Set.empty ~init ~f

  module C : Container.S0 with type t := t and type elt := Account.t =
  Container.Make0 (struct
    module Elt = Account

    type nonrec t = t

    let fold t ~init ~f =
      let f' _index accum account = f accum account in
      foldi t ~init ~f:f'

    let iter = `Define_using_fold
  end)

  let fold_until = C.fold_until

  let merkle_root mdb = get_hash mdb Location.root_hash

  let remove_accounts_exn t keys =
    let locations =
      (* if we don't have a location for all keys, raise an exception *)
      let rec loop keys accum =
        match keys with
        | [] -> accum (* no need to reverse *)
        | key :: rest -> (
          match Account_location.get t key with
          | Ok loc -> loop rest (loc :: accum)
          | Error err -> raise (Db_error.Db_exception err) )
      in
      loop keys []
    in
    (* N.B.: we're not using stack database here to make available newly-freed
       locations *)
    List.iter keys ~f:(Account_location.delete t) ;
    List.iter locations ~f:(fun loc -> delete_raw t loc) ;
    (* recalculate hashes for each removed account *)
    List.iter locations ~f:(fun loc ->
        let hash_loc = Location.Hash (Location.to_path_exn loc) in
        set_hash t hash_loc Hash.empty_account )

  let merkle_path mdb location =
    let location =
      if Location.is_account location then
        Location.Hash (Location.to_path_exn location)
      else location
    in
    assert (Location.is_hash location) ;
    let rec loop k =
      if Location.height k >= Depth.depth then []
      else
        let sibling = Location.sibling k in
        let sibling_dir = Location.last_direction (Location.to_path_exn k) in
        let hash = get_hash mdb sibling in
        Direction.map sibling_dir ~left:(`Left hash) ~right:(`Right hash)
        :: loop (Location.parent k)
    in
    loop location

  let merkle_path_at_addr_exn t addr = merkle_path t (Location.Hash addr)

  let merkle_path_at_index_exn t index =
    let addr = Addr.of_int_exn index in
    merkle_path_at_addr_exn t addr
end
