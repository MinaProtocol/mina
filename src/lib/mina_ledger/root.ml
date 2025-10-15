open Core
open Mina_base

module type Stable_db_intf =
  Merkle_ledger.Intf.Ledger.DATABASE
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t

module type Migrated_db_intf =
  Merkle_ledger.Intf.Ledger.DATABASE
    with type account := Account.Hardfork.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t

module type Any_ledger_intf =
  Merkle_ledger.Intf.Ledger.ANY
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t

module type Converting_ledger_intf =
  Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
    with type root_hash := Ledger_hash.t
     and type hash := Ledger_hash.t
     and type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type converted_account := Account.Hardfork.t

module Make
    (Any_ledger : Any_ledger_intf)
    (Stable_db : Stable_db_intf
                   with module Location = Any_ledger.M.Location
                    and module Addr = Any_ledger.M.Addr)
    (Migrated_db : Migrated_db_intf
                     with module Location = Any_ledger.M.Location
                      and module Addr = Any_ledger.M.Addr)
    (Converting_ledger : Converting_ledger_intf
                           with module Location = Any_ledger.M.Location
                            and module Addr = Any_ledger.M.Addr
                           with type primary_ledger = Stable_db.t
                            and type converting_ledger = Migrated_db.t) =
struct
  module Config = struct
    type backing_type = Stable_db | Converting_db [@@deriving equal, yojson]

    (* WARN: always construct Converting_db_config with
       [with_directory ~backing_type ~directory_name], instead of manual
       creation. This is because [delete_any_backing] expect there's a
       relation between primary dir and converting dir name *)
    type t =
      | Stable_db_config of string
      | Converting_db_config of Converting_ledger.Config.t
    [@@deriving yojson]

    let backing_of_config = function
      | Stable_db_config _ ->
          Stable_db
      | Converting_db_config _ ->
          Converting_db

    let file_exists path =
      Sys.file_exists path |> [%equal: [ `No | `Unknown | `Yes ]] `Yes

    let exists_backing = function
      | Stable_db_config path ->
          file_exists path
      | Converting_db_config { primary_directory; converting_directory } ->
          file_exists primary_directory && file_exists converting_directory

    let with_directory ~backing_type ~directory_name =
      match backing_type with
      | Stable_db ->
          Stable_db_config directory_name
      | Converting_db ->
          Converting_db_config
            (Converting_ledger.Config.with_primary ~directory_name)

    let delete_any_backing config =
      let primary, converting =
        match config with
        | Stable_db_config primary ->
            let converting =
              Converting_ledger.Config.default_converting_directory_name primary
            in
            (primary, converting)
        | Converting_db_config { primary_directory; converting_directory } ->
            (primary_directory, converting_directory)
      in
      Mina_stdlib_unix.File_system.rmrf primary ;
      Mina_stdlib_unix.File_system.rmrf converting

    let delete_backing = function
      | Stable_db_config primary ->
          Mina_stdlib_unix.File_system.rmrf primary
      | Converting_db_config { primary_directory; converting_directory } ->
          Mina_stdlib_unix.File_system.rmrf primary_directory ;
          Mina_stdlib_unix.File_system.rmrf converting_directory

    exception
      Backing_mismatch of { backing_1 : backing_type; backing_2 : backing_type }

    let move_backing_exn ~src ~dst =
      match (src, dst) with
      | Stable_db_config src, Stable_db_config dst ->
          Sys.rename src dst
      | ( Converting_db_config
            { primary_directory = src_primary
            ; converting_directory = src_converted
            }
        , Converting_db_config
            { primary_directory = dst_primary
            ; converting_directory = dst_converted
            } ) ->
          Sys.rename src_primary dst_primary ;
          Sys.rename src_converted dst_converted
      | cfg1, cfg2 ->
          raise
            (Backing_mismatch
               { backing_1 = backing_of_config cfg1
               ; backing_2 = backing_of_config cfg2
               } )
  end

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  type t = Stable_db of Stable_db.t | Converting_db of Converting_ledger.t

  let backing_of_t = function
    | Stable_db _ ->
        Config.Stable_db
    | Converting_db _ ->
        Converting_db

  let close t =
    match t with
    | Stable_db db ->
        Stable_db.close db
    | Converting_db db ->
        Converting_ledger.close db

  let merkle_root t =
    match t with
    | Stable_db db ->
        Stable_db.merkle_root db
    | Converting_db db ->
        Converting_ledger.merkle_root db

  let create ~logger ~config ~depth ?(assert_synced = false) () =
    match config with
    | Config.Stable_db_config directory_name ->
        Stable_db (Stable_db.create ~directory_name ~depth ())
    | Converting_db_config config ->
        Converting_db
          (Converting_ledger.create ~config:(In_directories config) ~logger
             ~depth ~assert_synced () )

  let create_temporary ~logger ~backing_type ~depth () =
    match backing_type with
    | Config.Stable_db ->
        Stable_db (Stable_db.create ~depth ())
    | Converting_db ->
        Converting_db
          (Converting_ledger.create ~config:Temporary ~logger ~depth ())

  let create_checkpoint t ~config () =
    match (t, config) with
    | Stable_db db, Config.Stable_db_config directory_name ->
        Stable_db (Stable_db.create_checkpoint db ~directory_name ())
    | Converting_db db, Converting_db_config config ->
        Converting_db (Converting_ledger.create_checkpoint db ~config ())
    | t, config ->
        raise
          (Config.Backing_mismatch
             { backing_1 = backing_of_t t
             ; backing_2 = Config.backing_of_config config
             } )

  let make_checkpoint t ~config =
    match (t, config) with
    | Stable_db db, Config.Stable_db_config directory_name ->
        Stable_db.make_checkpoint db ~directory_name
    | Converting_db db, Converting_db_config config ->
        Converting_ledger.make_checkpoint db ~config
    | t, config ->
        raise
          (Config.Backing_mismatch
             { backing_1 = backing_of_t t
             ; backing_2 = Config.backing_of_config config
             } )

  let create_checkpoint_with_directory t ~directory_name =
    let backing_type =
      match t with
      | Stable_db _db ->
          Config.Stable_db
      | Converting_db _db ->
          Config.Converting_db
    in
    let config = Config.with_directory ~backing_type ~directory_name in
    create_checkpoint t ~config ()

  (** Migrate the accounts in the ledger database [stable_db] and store them in
      [empty_hardfork_db]. The accounts are set in the target database in chunks
      so the daemon is still responsive during this operation; the daemon would
      otherwise stop everything as it hashed every account in the list. *)
  let chunked_migration ?(chunk_size = 1 lsl 6) stable_locations_and_accounts
      empty_migrated_db =
    let open Async.Deferred.Let_syntax in
    let ledger_depth = Migrated_db.depth empty_migrated_db in
    let addrs_and_accounts =
      List.mapi stable_locations_and_accounts ~f:(fun i acct ->
          ( Migrated_db.Addr.of_int_exn ~ledger_depth i
          , Account.Hardfork.of_stable acct ) )
    in
    let rec set_chunks accounts =
      let%bind () = Async_unix.Scheduler.yield () in
      let chunk, accounts' = List.split_n accounts chunk_size in
      if List.is_empty chunk then return empty_migrated_db
      else (
        Migrated_db.set_batch_accounts empty_migrated_db chunk ;
        set_chunks accounts' )
    in
    set_chunks addrs_and_accounts

  let make_converting t =
    let open Async.Deferred.Let_syntax in
    match t with
    | Converting_db _db ->
        return t
    | Stable_db db ->
        let directory_name =
          Stable_db.get_directory db
          |> Option.value_exn
               ~message:"Invariant: database must be in a directory"
        in
        let converting_config =
          Converting_ledger.Config.with_primary ~directory_name
        in
        let migrated_db =
          Migrated_db.create
            ~directory_name:converting_config.converting_directory
            ~depth:(Stable_db.depth db) ()
        in
        let%map migrated_db =
          chunked_migration (Stable_db.to_list_sequential db) migrated_db
        in
        Converting_db (Converting_ledger.of_ledgers db migrated_db)

  let as_unmasked t =
    match t with
    | Stable_db db ->
        Any_ledger.cast (module Stable_db) db
    | Converting_db db ->
        Any_ledger.cast (module Converting_ledger) db

  let depth t =
    match t with
    | Stable_db db ->
        Stable_db.depth db
    | Converting_db db ->
        Converting_ledger.depth db

  let num_accounts t =
    match t with
    | Stable_db db ->
        Stable_db.num_accounts db
    | Converting_db db ->
        Converting_ledger.depth db

  let merkle_path_at_addr_exn t =
    match t with
    | Stable_db db ->
        Stable_db.merkle_path_at_addr_exn db
    | Converting_db db ->
        Converting_ledger.merkle_path_at_addr_exn db

  let get_inner_hash_at_addr_exn t =
    match t with
    | Stable_db db ->
        Stable_db.get_inner_hash_at_addr_exn db
    | Converting_db db ->
        Converting_ledger.get_inner_hash_at_addr_exn db

  let set_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Stable_db.set_all_accounts_rooted_at_exn db
    | Converting_db db ->
        Converting_ledger.set_all_accounts_rooted_at_exn db

  let set_batch_accounts t =
    match t with
    | Stable_db db ->
        Stable_db.set_batch_accounts db
    | Converting_db db ->
        Converting_ledger.set_batch_accounts db

  let get_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Stable_db.get_all_accounts_rooted_at_exn db
    | Converting_db db ->
        Converting_ledger.get_all_accounts_rooted_at_exn db

  let unsafely_decompose_root t =
    match t with
    | Stable_db db ->
        (db, None)
    | Converting_db db ->
        ( Converting_ledger.primary_ledger db
        , Some (Converting_ledger.converting_ledger db) )
end
