module Make (Inputs : Intf.Inputs.DATABASE) = struct
  (* The max depth of a merkle tree can never be greater than 253. *)
  open Inputs

  module Db_error = struct
    [@@@warning "-4"] (* due to deriving sexp below *)

    type t = Account_location_not_found | Out_of_leaves | Malformed_database
    [@@deriving sexp]
  end

  module Path = Merkle_path.Make (Hash)
  module Addr = Location.Addr
  module Location = Location
  module Key = Key

  type location = Location.t [@@deriving sexp]

  type index = int

  type path = Path.t

  module Detached_parent_signal = struct
    type t = unit Async.Ivar.t

    let sexp_of_t (_ : t) = Sexp.List []

    let t_of_sexp (_ : Sexp.t) : t = Async.Ivar.create ()
  end

  type t =
    { uuid : Uuid.Stable.V1.t
    ; kvdb : (Kvdb.t[@sexp.opaque])
    ; depth : int
    ; directory : string
    ; detached_parent_signal : Detached_parent_signal.t
    }
  [@@deriving sexp]

  let get_uuid t = t.uuid

  let get_directory t = Some t.directory

  let depth t = t.depth

  let create ?directory_name ~depth () =
    let open Core in
    (* for ^/ and Unix below *)
    assert (depth < 0xfe) ;
    let uuid = Uuid_unix.create () in
    let directory =
      match directory_name with
      | None ->
          (* Create in the autogen path, where we know we have write
             permissions.
          *)
          Cache_dir.autogen_path ^/ Uuid.to_string uuid
      | Some name ->
          name
    in
    Unix.mkdir_p directory ;
    let kvdb = Kvdb.create directory in
    { uuid
    ; kvdb
    ; depth
    ; directory
    ; detached_parent_signal = Async.Ivar.create ()
    }

  let create_checkpoint t ~directory_name () =
    let uuid = Uuid_unix.create () in
    let kvdb = Kvdb.create_checkpoint t.kvdb directory_name in
    { uuid
    ; kvdb
    ; depth = t.depth
    ; directory = directory_name
    ; detached_parent_signal = Async.Ivar.create ()
    }

  let make_checkpoint t ~directory_name =
    Kvdb.make_checkpoint t.kvdb directory_name

  let close { kvdb; uuid = _; depth = _; directory = _; detached_parent_signal }
      =
    Kvdb.close kvdb ;
    Async.Ivar.fill_if_empty detached_parent_signal ()

  let detached_signal { detached_parent_signal; _ } =
    Async.Ivar.read detached_parent_signal

  let with_ledger ~depth ~f =
    let t = create ~depth () in
    try
      let result = f t in
      close t ; result
    with exn -> close t ; raise exn

  let empty_hash =
    Empty_hashes.extensible_cache (module Hash) ~init_hash:Hash.empty_account

  let get_raw { kvdb; depth; _ } location =
    Kvdb.get kvdb ~key:(Location.serialize ~ledger_depth:depth location)

  let get_raw_batch { kvdb; depth; _ } locations =
    let keys = List.map locations ~f:(Location.serialize ~ledger_depth:depth) in
    Kvdb.get_batch kvdb ~keys

  let get_bin mdb location bin_read =
    get_raw mdb location |> Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0))

  let get_bin_batch mdb locations bin_read =
    get_raw_batch mdb locations
    |> List.map ~f:(Option.map ~f:(fun v -> bin_read v ~pos_ref:(ref 0)))

  let delete_raw { kvdb; depth; _ } location =
    Kvdb.remove kvdb ~key:(Location.serialize ~ledger_depth:depth location)

  let get mdb location =
    assert (Location.is_account location) ;
    get_bin mdb location Account.bin_read_t

  let get_batch mdb locations =
    assert (List.for_all locations ~f:Location.is_account) ;
    List.zip_exn locations (get_bin_batch mdb locations Account.bin_read_t)

  let get_hash mdb location =
    assert (Location.is_hash location) ;
    match get_bin mdb location Hash.bin_read_t with
    | Some hash ->
        hash
    | None ->
        empty_hash (Location.height ~ledger_depth:mdb.depth location)

  let get_hash_batch_exn mdb locations =
    List.iter locations ~f:(fun location -> assert (Location.is_hash location)) ;
    let hashes = get_bin_batch mdb locations Hash.bin_read_t in
    List.map2_exn locations hashes ~f:(fun location hash ->
        match hash with
        | Some hash ->
            hash
        | None ->
            empty_hash (Location.height ~ledger_depth:mdb.depth location) )

  let set_raw { kvdb; depth; _ } location bin =
    Kvdb.set kvdb
      ~key:(Location.serialize ~ledger_depth:depth location)
      ~data:bin

  let set_raw_batch { kvdb; depth; _ } locations_bins =
    let serialize_location (loc, bin) =
      (Location.serialize ~ledger_depth:depth loc, bin)
    in
    let serialized = List.map locations_bins ~f:serialize_location in
    Kvdb.set_batch kvdb ~key_data_pairs:serialized

  let set_bin mdb location bin_size bin_write v =
    let buf = Bigstring.create (bin_size v) in
    ignore (bin_write buf ~pos:0 v : int) ;
    set_raw mdb location buf

  let set_bin_batch mdb bin_size bin_write locations_vs =
    let create_buf (loc, v) =
      let buf = Bigstring.create (bin_size v) in
      ignore (bin_write buf ~pos:0 v : int) ;
      (loc, buf)
    in
    let locs_bufs = List.map locations_vs ~f:create_buf in
    set_raw_batch ~remove_keys:[] mdb locs_bufs

  let get_inner_hash_at_addr_exn mdb address =
    assert (Addr.depth address <= mdb.depth) ;
    get_hash mdb (Location.Hash address)

  let set_inner_hash_at_addr_exn mdb address hash =
    assert (Addr.depth address <= mdb.depth) ;
    set_bin mdb (Location.Hash address) Hash.bin_size_t Hash.bin_write_t hash

  let get_generic mdb location =
    assert (Location.is_generic location) ;
    get_raw mdb location

  let get_generic_batch mdb locations =
    assert (List.for_all locations ~f:Location.is_generic) ;
    get_raw_batch mdb locations

  module Account_location = struct
    (** encodes a key, token_id pair as a location used as a database key, so
        we can find the account location associated with that key.
    *)
    let build_location account_id =
      Location.build_generic
        (Bigstring.of_string
           ( "$"
           ^ Format.sprintf
               !"%{sexp: Key.t}!%{sexp: Token_id.t}"
               (Account_id.public_key account_id)
               (Account_id.token_id account_id) ) )

    let serialize_kv ~ledger_depth (aid, location) =
      ( Location.serialize ~ledger_depth @@ build_location aid
      , Location.serialize ~ledger_depth location )

    let get mdb key =
      match get_generic mdb (build_location key) with
      | None ->
          Error Db_error.Account_location_not_found
      | Some location_bin ->
          Location.parse ~ledger_depth:mdb.depth location_bin
          |> Result.map_error ~f:(fun () -> Db_error.Malformed_database)

    let get_batch mdb keys =
      let parse_location bin =
        match Location.parse ~ledger_depth:mdb.depth bin with
        | Ok loc ->
            Some loc
        | Error () ->
            None
      in
      List.map keys ~f:build_location
      |> get_generic_batch mdb
      |> List.map ~f:(Option.bind ~f:parse_location)

    let set mdb key location =
      set_raw mdb (build_location key)
        (Location.serialize ~ledger_depth:mdb.depth location)

    let set_batch_create ~ledger_depth keys_to_locations =
      List.map ~f:(serialize_kv ~ledger_depth) keys_to_locations

    let _set_batch mdb keys_to_locations =
      Kvdb.set_batch mdb.kvdb
        ~key_data_pairs:
          (set_batch_create ~ledger_depth:mdb.depth keys_to_locations)

    let last_location_key () =
      Location.build_generic (Bigstring.of_string "last_account_location")

    let serialize_last_account_kv ~ledger_depth (location, last_account_location)
        =
      ( Location.serialize ~ledger_depth location
      , Location.serialize ~ledger_depth last_account_location )

    let increment_last_account_location mdb =
      let location = last_location_key () in
      let ledger_depth = mdb.depth in
      match get_generic mdb location with
      | None ->
          let first_location =
            Location.Account
              ( Addr.of_directions
              @@ List.init mdb.depth ~f:(fun _ -> Direction.Left) )
          in
          set_raw mdb location (Location.serialize ~ledger_depth first_location) ;
          Result.return first_location
      | Some prev_location -> (
          match Location.parse ~ledger_depth:mdb.depth prev_location with
          | Error () ->
              Error Db_error.Malformed_database
          | Ok prev_account_location ->
              Location.next prev_account_location
              |> Result.of_option ~error:Db_error.Out_of_leaves
              |> Result.map ~f:(fun next_account_location ->
                     set_raw mdb location
                       (Location.serialize ~ledger_depth next_account_location) ;
                     next_account_location ) )

    let allocate mdb key =
      let location_result = increment_last_account_location mdb in
      Result.map location_result ~f:(fun location ->
          set mdb key location ; location )

    let last_location mdb =
      last_location_key () |> get_raw mdb
      |> Option.bind ~f:(fun data ->
             Location.parse ~ledger_depth:mdb.depth data |> Result.ok )

    let last_location_address mdb =
      Option.map (last_location mdb) ~f:Location.to_path_exn
  end

  let get_at_index_exn mdb index =
    let addr = Addr.of_int_exn ~ledger_depth:mdb.depth index in
    get mdb (Location.Account addr) |> Option.value_exn

  let all_accounts (t : t) =
    match Account_location.last_location_address t with
    | None ->
        Sequence.empty
    | Some last_addr ->
        Sequence.range ~stop:`inclusive 0 (Addr.to_int last_addr)
        |> Sequence.map ~f:(fun i -> get_at_index_exn t i)

  (** The tokens associated with each public key.

      These are represented as a [Token_id.Set.t], which is represented by an
      ordered list.
  *)
  module Tokens = struct
    module Owner = struct
      (* Map token IDs to the owning account *)

      let build_location token_id =
        Location.build_generic
          (Bigstring.of_string
             (Format.sprintf !"$tid!%{sexp: Token_id.t}" token_id) )

      let serialize_kv ~ledger_depth ((tid : Token_id.t), (aid : Account_id.t))
          =
        let aid_buf =
          Bin_prot.Common.create_buf (Account_id.Stable.Latest.bin_size_t aid)
        in
        ignore (Account_id.Stable.Latest.bin_write_t aid_buf ~pos:0 aid : int) ;
        (Location.serialize ~ledger_depth (build_location tid), aid_buf)

      let get (mdb : t) (token_id : Token_id.t) : Account_id.t option =
        get_bin mdb (build_location token_id)
          Account_id.Stable.Latest.bin_read_t

      let set (mdb : t) (token_id : Token_id.t) (account_id : Account_id.t) :
          unit =
        set_bin mdb (build_location token_id)
          Account_id.Stable.Latest.bin_size_t
          Account_id.Stable.Latest.bin_write_t account_id

      let all_owners (t : t) : (Token_id.t * Account_id.t) Sequence.t =
        let deduped_tokens =
          (* First get the sequence of unique tokens *)
          Sequence.folding_map (all_accounts t) ~init:Token_id.Set.empty
            ~f:(fun (seen : Token_id.Set.t) (a : Account.t) ->
              let token = Account.token a in
              let already_seen = Token_id.Set.mem seen token in
              (Set.add seen token, (already_seen, token)) )
          |> Sequence.filter_map ~f:(fun (already_seen, token) ->
                 if already_seen then None else Some token )
        in
        Sequence.filter_map deduped_tokens ~f:(fun token ->
            Option.map (get t token) ~f:(fun owner -> (token, owner)) )

      let foldi (type a) (t : t) ~(init : a)
          ~(f : key:Token_id.t -> data:Account_id.t -> a -> a) : a =
        Sequence.fold (all_owners t) ~init ~f:(fun acc (key, data) ->
            f ~key ~data acc )

      let _iteri t ~f = foldi t ~init:() ~f:(fun ~key ~data () -> f ~key ~data)
    end

    let build_location pk =
      Location.build_generic
        (Bigstring.of_string (Format.sprintf !"$tids!%{sexp: Key.t}" pk))

    let serialize_kv ~ledger_depth (pk, tids) =
      let tokens_buf =
        Bin_prot.Common.create_buf (Token_id.Set.bin_size_t tids)
      in
      ignore (Token_id.Set.bin_write_t tokens_buf ~pos:0 tids : int) ;
      (Location.serialize ~ledger_depth (build_location pk), tokens_buf)

    let get_opt mdb pk = get_bin mdb (build_location pk) Token_id.Set.bin_read_t

    let get mdb pk = Option.value ~default:Token_id.Set.empty (get_opt mdb pk)

    let set mdb pk tids =
      set_bin mdb (build_location pk) Token_id.Set.bin_size_t
        Token_id.Set.bin_write_t tids

    let delete mdb pk = delete_raw mdb (build_location pk)

    let change_opt mdb pk ~f =
      let old = get_opt mdb pk in
      match (old, f old) with
      | _, Some tids ->
          set mdb pk tids
      | Some _, None ->
          delete mdb pk
      | None, None ->
          ()

    let to_opt s = if Set.is_empty s then None else Some s

    let _update_opt mdb pk ~f = change_opt mdb pk ~f:(fun x -> to_opt (f x))

    let update mdb pk ~f =
      change_opt mdb pk ~f:(fun x ->
          to_opt @@ f (Option.value ~default:Token_id.Set.empty x) )

    let add mdb pk tid = update mdb pk ~f:(fun tids -> Set.add tids tid)

    let _add_several mdb pk new_tids =
      update mdb pk ~f:(fun tids ->
          Set.union tids (Token_id.Set.of_list new_tids) )

    let add_account (mdb : t) (aid : Account_id.t) : unit =
      let token = Account_id.token_id aid in
      let key = Account_id.public_key aid in
      add mdb key token ;
      (* TODO: The owner DB will store a lot of these unnecessarily since
         most accounts are not going to be managers. *)
      Owner.set mdb (Account_id.derive_token_id ~owner:aid) aid

    let _remove_several mdb pk rem_tids =
      update mdb pk ~f:(fun tids ->
          Set.diff tids (Token_id.Set.of_list rem_tids) )

    (** Generate a batch of database changes to add the given tokens. *)
    let add_batch_create mdb pks_to_tokens =
      let pks_to_all_tokens =
        Map.filter_mapi pks_to_tokens ~f:(fun ~key:pk ~data:tokens_to_add ->
            to_opt (Set.union (get mdb pk) tokens_to_add) )
      in
      Map.to_alist pks_to_all_tokens
      |> List.map ~f:(serialize_kv ~ledger_depth:mdb.depth)

    let _add_batch mdb pks_to_tokens =
      Kvdb.set_batch mdb.kvdb
        ~key_data_pairs:(add_batch_create mdb pks_to_tokens)
  end

  let location_of_account t key =
    match Account_location.get t key with
    | Error _ ->
        None
    | Ok location ->
        Some location

  let location_of_account_batch t keys =
    List.zip_exn keys (Account_location.get_batch t keys)

  let last_filled t = Account_location.last_location t

  let token_owners (t : t) : Account_id.Set.t =
    Tokens.Owner.all_owners t
    |> Sequence.fold ~init:Account_id.Set.empty ~f:(fun acc (_, owner) ->
           Set.add acc owner )

  let token_owner = Tokens.Owner.get

  let tokens = Tokens.get

  include Util.Make (struct
    module Key = Key
    module Token_id = Token_id
    module Account_id = Account_id
    module Balance = Balance
    module Location = Location
    module Location_binable = Location_binable
    module Account = Account
    module Hash = Hash

    module Base = struct
      type nonrec t = t

      let get = get

      let last_filled = last_filled
    end

    let get_hash = get_hash

    let ledger_depth = depth

    let location_of_account_addr addr = Location.Account addr

    let location_of_hash_addr addr = Location.Hash addr

    let set_raw_hash_batch mdb addresses_and_hashes =
      set_bin_batch mdb Hash.bin_size_t Hash.bin_write_t addresses_and_hashes

    let set_location_batch ~last_location mdb key_to_location_list =
      let last_location_key_value =
        (Account_location.last_location_key (), last_location)
      in
      let key_to_location_list =
        Mina_stdlib.Nonempty_list.to_list key_to_location_list
      in
      let account_tokens =
        List.fold ~init:Key.Map.empty key_to_location_list
          ~f:(fun map (aid, _) ->
            Map.update map (Account_id.public_key aid) ~f:(function
              | Some set ->
                  Set.add set (Account_id.token_id aid)
              | None ->
                  Token_id.Set.singleton (Account_id.token_id aid) ) )
      in
      let batched_changes =
        Account_location.serialize_last_account_kv ~ledger_depth:mdb.depth
          last_location_key_value
        :: ( Tokens.add_batch_create mdb account_tokens
           @ Account_location.set_batch_create ~ledger_depth:mdb.depth
               key_to_location_list )
      in
      Kvdb.set_batch mdb.kvdb ~remove_keys:[] ~key_data_pairs:batched_changes

    let set_raw_account_batch mdb
        (addresses_and_accounts : (location * Account.t) list) =
      set_bin_batch mdb Account.bin_size_t Account.bin_write_t
        addresses_and_accounts ;
      let token_owner_changes =
        List.map addresses_and_accounts ~f:(fun (_, account) ->
            let aid = Account.identifier account in
            Tokens.Owner.serialize_kv ~ledger_depth:mdb.depth
              (Account_id.derive_token_id ~owner:aid, aid) )
      in
      Kvdb.set_batch mdb.kvdb ~remove_keys:[]
        ~key_data_pairs:token_owner_changes
  end)

  let set_hash mdb location new_hash =
    set_hash_batch mdb [ (location, new_hash) ]

  module For_tests = struct
    let gen_account_location ~ledger_depth =
      let open Quickcheck.Let_syntax in
      let build_account (path : Direction.t list) =
        assert (List.length path = ledger_depth) ;
        Location.Account (Addr.of_directions path)
      in
      let%map dirs =
        Quickcheck.Generator.list_with_length ledger_depth Direction.gen
      in
      build_account dirs
  end

  let set mdb location account =
    set_bin mdb location Account.bin_size_t Account.bin_write_t account ;
    set_hash mdb
      (Location.Hash (Location.to_path_exn location))
      (Hash.hash_account account)

  let index_of_account_exn mdb account_id =
    let location = location_of_account mdb account_id |> Option.value_exn in
    let addr = Location.to_path_exn location in
    Addr.to_int addr

  let set_at_index_exn mdb index account =
    let addr = Addr.of_int_exn ~ledger_depth:mdb.depth index in
    set mdb (Location.Account addr) account

  let num_accounts t =
    match Account_location.last_location_address t with
    | None ->
        0
    | Some addr ->
        Addr.to_int addr + 1

  let to_list mdb =
    let num_accounts = num_accounts mdb in
    Async.Deferred.List.init ~how:`Parallel num_accounts ~f:(fun i ->
        Async.Deferred.return @@ get_at_index_exn mdb i )

  let to_list_sequential mdb =
    let num_accounts = num_accounts mdb in
    List.init num_accounts ~f:(fun i -> get_at_index_exn mdb i)

  let accounts mdb =
    let%map.Async.Deferred accts = to_list mdb in
    List.map accts ~f:Account.identifier |> Account_id.Set.of_list

  let get_or_create_account mdb account_id account =
    match Account_location.get mdb account_id with
    | Error Db_error.Account_location_not_found -> (
        match Account_location.allocate mdb account_id with
        | Ok location ->
            set mdb location account ;
            Tokens.add_account mdb account_id ;
            Ok (`Added, location)
        | Error err ->
            Error (Error.create "get_or_create_account" err Db_error.sexp_of_t)
        )
    | Error ((Db_error.Malformed_database | Db_error.Out_of_leaves) as err) ->
        Error (Error.create "get_or_create_account" err Db_error.sexp_of_t)
    | Ok location ->
        Ok (`Existed, location)

  let iteri t ~f =
    match Account_location.last_location_address t with
    | None ->
        ()
    | Some last_addr ->
        Sequence.range ~stop:`inclusive 0 (Addr.to_int last_addr)
        |> Sequence.iter ~f:(fun i -> f i (get_at_index_exn t i))

  (* TODO : if key-value store supports iteration mechanism, like RocksDB,
     maybe use that here, instead of loading all accounts into memory See Issue
     #1191 *)
  let foldi_with_ignored_accounts t ignored_accounts ~init ~f =
    let f' index accum account =
      f (Addr.of_int_exn ~ledger_depth:(depth t) index) accum account
    in
    match Account_location.last_location_address t with
    | None ->
        init
    | Some last_addr ->
        let ignored_indices =
          Int.Set.map ignored_accounts ~f:(fun account_id ->
              try index_of_account_exn t account_id with _ -> -1
              (* dummy index for accounts not in database *) )
        in
        let last = Addr.to_int last_addr in
        Sequence.range ~stop:`inclusive 0 last
        (* filter out indices corresponding to ignored accounts *)
        |> Sequence.filter ~f:(fun loc -> not (Int.Set.mem ignored_indices loc))
        |> Sequence.map ~f:(get_at_index_exn t)
        |> Sequence.foldi ~init ~f:f'

  let foldi t ~init ~f =
    foldi_with_ignored_accounts t Account_id.Set.empty ~init ~f

  let fold_until t ~init ~f ~finish =
    let%map.Async.Deferred accts = to_list t in
    List.fold_until accts ~init ~f ~finish

  let merkle_root mdb = get_hash mdb Location.root_hash

  let merkle_path mdb location =
    let location =
      if Location.is_account location then
        Location.Hash (Location.to_path_exn location)
      else location
    in
    let dependency_locs, dependency_dirs =
      List.unzip (Location.merkle_path_dependencies_exn location)
    in
    let dependency_hashes = get_hash_batch_exn mdb dependency_locs in
    List.map2_exn dependency_dirs dependency_hashes ~f:(fun dir hash ->
        Direction.map dir ~left:(`Left hash) ~right:(`Right hash) )

  let path_batch_impl ~expand_query ~compute_path mdb locations =
    let locations =
      List.map locations ~f:(fun location ->
          if Location.is_account location then
            Location.Hash (Location.to_path_exn location)
          else (
            assert (Location.is_hash location) ;
            location ) )
    in
    let list_of_dependencies =
      List.map locations ~f:Location.merkle_path_dependencies_exn
    in
    let all_locs =
      List.map list_of_dependencies ~f:(fun deps ->
          List.map ~f:fst deps |> expand_query )
      |> List.concat
    in
    let hashes = get_hash_batch_exn mdb all_locs in
    snd @@ List.fold_map ~init:hashes ~f:compute_path list_of_dependencies

  let merkle_path_batch =
    path_batch_impl ~expand_query:ident
      ~compute_path:(fun all_hashes loc_and_dir_list ->
        let len = List.length loc_and_dir_list in
        let sibling_hashes, rest_hashes = List.split_n all_hashes len in
        let res =
          List.map2_exn loc_and_dir_list sibling_hashes
            ~f:(fun (_, direction) sibling_hash ->
              Direction.map direction ~left:(`Left sibling_hash)
                ~right:(`Right sibling_hash) )
        in
        (rest_hashes, res) )

  let wide_merkle_path_batch =
    path_batch_impl
      ~expand_query:(fun sib_locs ->
        sib_locs @ List.map sib_locs ~f:Location.sibling )
      ~compute_path:(fun all_hashes loc_and_dir_list ->
        let len = List.length loc_and_dir_list in
        let sibling_hashes, rest_hashes = List.split_n all_hashes len in
        let self_hashes, rest_hashes' = List.split_n rest_hashes len in
        let res =
          List.map3_exn loc_and_dir_list sibling_hashes self_hashes
            ~f:(fun (_, direction) sibling_hash self_hash ->
              Direction.map direction
                ~left:(`Left (self_hash, sibling_hash))
                ~right:(`Right (sibling_hash, self_hash)) )
        in
        (rest_hashes', res) )

  let merkle_path_at_addr_exn t addr = merkle_path t (Location.Hash addr)

  let merkle_path_at_index_exn t index =
    let addr = Addr.of_int_exn ~ledger_depth:t.depth index in
    merkle_path_at_addr_exn t addr
end
