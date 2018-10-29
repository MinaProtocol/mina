open Core

module Make (Key : sig
  include Intf.Key

  val to_string : t -> string
end)
(Account : Intf.Account with type key := Key.t)
(Hash : Intf.Hash with type account := Account.t)
(Depth : Intf.Depth)
(Location : Location_intf.S)
(Kvdb : Intf.Key_value_database)
(Sdb : Intf.Stack_database)
(Storage_locations : Intf.Storage_locations) :
  Database_intf.S
  with module Addr = Location.Addr
  with type account := Account.t
   and type hash := Hash.t
   and type key := Key.t
   and type location := Location.t = struct
  (* The max depth of a merkle tree can never be greater than 253. *)
  include Depth

  let () = assert (Depth.depth < 0xfe)

  module Db_error = struct
    type t = Account_location_not_found | Out_of_leaves | Malformed_database
    [@@deriving sexp]
  end

  module Path = Merkle_path.Make (Hash)
  module Addr = Location.Addr

  type location = Location.t [@@deriving sexp]

  type t = {kvdb: Kvdb.t sexp_opaque; sdb: Sdb.t sexp_opaque} [@@deriving sexp]

  let create () =
    let kvdb = Kvdb.create ~directory:Storage_locations.key_value_db_dir in
    let sdb = Sdb.create ~filename:Storage_locations.stack_db_file in
    {kvdb; sdb}

  let destroy {kvdb; sdb} = Kvdb.destroy kvdb ; Sdb.destroy sdb

  let empty_hashes =
    let empty_hashes =
      Array.create ~len:(Depth.depth + 1) Hash.empty_account
    in
    let rec loop last_hash height =
      if height <= Depth.depth then (
        let hash = Hash.merge ~height:(height - 1) last_hash last_hash in
        empty_hashes.(height) <- hash ;
        loop hash (height + 1) )
    in
    loop Hash.empty_account 1 ;
    Immutable_array.of_array empty_hashes

  let get_raw {kvdb; _} location =
    Kvdb.get kvdb ~key:(Location.serialize location)

  let get_bin mdb location bin_read =
    get_raw mdb location |> Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0))

  let get_generic mdb location =
    assert (Location.is_generic location) ;
    get_raw mdb location

  let get mdb location =
    assert (Location.is_account location) ;
    get_bin mdb location Account.bin_read_t

  let get_hash mdb location =
    assert (Location.is_hash location) ;
    match get_bin mdb location Hash.bin_read_t with
    | Some hash -> hash
    | None -> Immutable_array.get empty_hashes (Location.height location)

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

  let rec set_hash mdb location new_hash =
    assert (Location.is_hash location) ;
    set_bin mdb location Hash.bin_size_t Hash.bin_write_t new_hash ;
    let height = Location.height location in
    if height < Depth.depth then
      let sibling_hash = get_hash mdb (Location.sibling location) in
      let parent_hash =
        let left_hash, right_hash =
          Location.order_siblings location new_hash sibling_hash
        in
        assert (height <= Depth.depth) ;
        Hash.merge ~height left_hash right_hash
      in
      set_hash mdb (Location.parent location) parent_hash

  let get_inner_hash_at_addr_exn mdb address =
    assert (Addr.depth address <= Depth.depth) ;
    get_hash mdb (Location.Hash address)

  let set_inner_hash_at_addr_exn mdb address hash =
    assert (Addr.depth address <= Depth.depth) ;
    set_bin mdb (Location.Hash address) Hash.bin_size_t Hash.bin_write_t hash

  let make_space_for _t _tot = ()

  module Account_location = struct
    let build_location key =
      Location.build_generic (Bigstring.of_string ("$" ^ Key.to_string key))

    let get mdb key =
      match get_generic mdb (build_location key) with
      | None -> Error Db_error.Account_location_not_found
      | Some location_bin ->
          Location.parse location_bin
          |> Result.map_error ~f:(fun () -> Db_error.Malformed_database)

    let set mdb key location = set_raw mdb (build_location key) location

    let last_location () =
      Location.build_generic (Bigstring.of_string "last_account_location")

    let increment_last_account_location mdb =
      let location = last_location () in
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
      let location_result =
        match Sdb.pop mdb.sdb with
        | None -> increment_last_account_location mdb
        | Some location ->
            Location.parse location
            |> Result.map_error ~f:(fun () -> Db_error.Malformed_database)
      in
      Result.map location_result ~f:(fun location ->
          set mdb key (Location.serialize location) ;
          location )

    let last_location_address mdb =
      match
        last_location () |> get_raw mdb |> Result.of_option ~error:()
        |> Result.bind ~f:Location.parse
      with
      | Error () -> None
      | Ok parsed_location -> Some (Location.to_path_exn parsed_location)
  end

  let location_of_key t key =
    match Account_location.get t key with
    | Error _ -> None
    | Ok location -> Some location

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

  let set_batch mdb locations_accounts =
    set_bin_batch mdb Account.bin_size_t Account.bin_write_t locations_accounts ;
    let set_one_hash (location, account) =
      set_hash mdb
        (Location.Hash (Location.to_path_exn location))
        (Hash.hash_account account)
    in
    (* TODO: is there something better we can do? *)
    List.iter locations_accounts ~f:set_one_hash

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
    | Error Account_location_not_found ->
        Account_location.allocate mdb key
        |> Result.map ~f:(fun location ->
               set mdb location account ;
               (`Added, location) )
    | Error err -> Error err
    | Ok location -> Ok (`Existed, location)

  exception Error_exception of Db_error.t

  let get_or_create_account_exn mdb key account =
    get_or_create_account mdb key account
    |> Result.map_error ~f:(fun err -> Error_exception err)
    |> Result.ok_exn

  let num_accounts t =
    match Account_location.last_location_address t with
    | None -> 0
    | Some addr -> Addr.to_int addr - Sdb.length t.sdb + 1

  let get_all_accounts_rooted_at_exn mdb address =
    let first_node, last_node = Addr.Range.subtree_range address in
    let result =
      Addr.Range.fold (first_node, last_node) ~init:[] ~f:(fun bit_index acc ->
          let account = get mdb (Location.Account bit_index) in
          account :: acc )
    in
    List.rev_filter_map result ~f:Fn.id

  let set_all_accounts_rooted_at_exn mdb address (accounts : Account.t list) =
    let first_node, last_node = Addr.Range.subtree_range address in
    Addr.Range.fold (first_node, last_node) ~init:accounts ~f:(fun bit_index ->
      function
      | head :: tail ->
          set mdb (Location.Account bit_index) head ;
          tail
      | [] -> [] )
    |> ignore

  module C : Container.S0 with type t := t and type elt := Account.t =
  Container.Make0 (struct
    module Elt = Account

    type nonrec t = t

    (* TODO: This implementation does not consider empty indices from stack db. *)
    let fold t ~init ~f =
      match Account_location.last_location_address t with
      | None -> init
      | Some last_addr ->
          let last = Addr.to_int last_addr in
          Sequence.range ~stop:`inclusive 0 last
          |> Sequence.map ~f:(get_at_index_exn t)
          |> Sequence.fold ~init ~f

    let iter = `Define_using_fold
  end)

  let to_list = C.to_list

  let merkle_root mdb = get_hash mdb Location.root_hash

  let copy {kvdb; sdb} = {kvdb= Kvdb.copy kvdb; sdb= Sdb.copy sdb}

  let remove_accounts_exn _ _ = failwith "TODO: Implement"

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
