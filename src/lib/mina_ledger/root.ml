open Async
open Core
open Mina_base

module Config = struct
  type backing_type =
    | Stable_db
    | Converting_db of Mina_numbers.Global_slot_since_genesis.t
  [@@deriving equal, yojson]

  (* WARN: always construct Converting_db_config with
     [with_directory ~backing_type ~directory_name], instead of manual
     creation. This is because [delete_any_backing] expect there's a
     relation between primary dir and converting dir name *)
  type t =
    | Stable_db_config of string
    | Converting_db_config of
        { db_config :
            Merkle_ledger.Converting_merkle_tree.With_database_config.t
        ; hardfork_slot : Mina_numbers.Global_slot_since_genesis.t
        }
  [@@deriving yojson]

  let backing_of_config = function
    | Stable_db_config _ ->
        Stable_db
    | Converting_db_config { hardfork_slot; _ } ->
        Converting_db hardfork_slot

  let file_exists path =
    Sys.file_exists path |> [%equal: [ `No | `Unknown | `Yes ]] `Yes

  let exists_backing = function
    | Stable_db_config path ->
        file_exists path
    | Converting_db_config
        { db_config = { primary_directory; converting_directory }; _ } ->
        file_exists primary_directory && file_exists converting_directory

  let exists_any_backing = function
    | Stable_db_config path ->
        file_exists path
    | Converting_db_config { db_config = { primary_directory; _ }; _ } ->
        file_exists primary_directory

  let with_directory ~backing_type ~directory_name =
    match backing_type with
    | Stable_db ->
        Stable_db_config directory_name
    | Converting_db hardfork_slot ->
        Converting_db_config
          { db_config =
              Merkle_ledger.Converting_merkle_tree.With_database_config
              .with_primary ~directory_name
          ; hardfork_slot
          }

  let delete_any_backing config =
    let primary, converting =
      match config with
      | Stable_db_config primary ->
          let converting =
            Merkle_ledger.Converting_merkle_tree.With_database_config
            .default_converting_directory_name primary
          in
          (primary, converting)
      | Converting_db_config
          { db_config = { primary_directory; converting_directory }; _ } ->
          (primary_directory, converting_directory)
    in
    Mina_stdlib_unix.File_system.rmrf primary ;
    Mina_stdlib_unix.File_system.rmrf converting

  let delete_backing = function
    | Stable_db_config primary ->
        Mina_stdlib_unix.File_system.rmrf primary
    | Converting_db_config
        { db_config = { primary_directory; converting_directory }; _ } ->
        Mina_stdlib_unix.File_system.rmrf primary_directory ;
        Mina_stdlib_unix.File_system.rmrf converting_directory

  exception
    Backing_mismatch of { backing_1 : backing_type; backing_2 : backing_type }

  let move_backing_exn ~src ~dst =
    match (src, dst) with
    | Stable_db_config src, Stable_db_config dst ->
        Sys.rename src dst
    | ( Converting_db_config
          { db_config =
              { primary_directory = src_primary
              ; converting_directory = src_converted
              }
          ; _
          }
      , Converting_db_config
          { db_config =
              { primary_directory = dst_primary
              ; converting_directory = dst_converted
              }
          ; _
          } ) ->
        Sys.rename src_primary dst_primary ;
        Sys.rename src_converted dst_converted
    | cfg1, cfg2 ->
        raise
          (Backing_mismatch
             { backing_1 = backing_of_config cfg1
             ; backing_2 = backing_of_config cfg2
             } )

  let primary_directory config =
    match config with
    | Stable_db_config src ->
        src
    | Converting_db_config { db_config = { primary_directory; _ }; _ } ->
        primary_directory
end

module T = struct
  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Ledger.Db.Addr.t

  type path = Ledger.Db.path

  module type Converting_ledger =
    Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
      with module Location = Ledger.Location
       and module Addr = Ledger.Location.Addr
      with type root_hash := Ledger_hash.t
       and type hash := Ledger_hash.t
       and type account := Account.t
       and type key := Signature_lib.Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t
       and type converted_account := Account.Hardfork.t
       and type primary_ledger = Ledger.Db.t
       and type converting_ledger = Ledger.Hardfork_db.t

  type t =
    | Stable_db : Ledger.Db.t -> t
    | Converting_db :
        (module Converting_ledger with type t = 't)
        * 't
        * Mina_numbers.Global_slot_since_genesis.t
        -> t

  let backing_of_t = function
    | Stable_db _ ->
        Config.Stable_db
    | Converting_db (_, _, hardfork_slot) ->
        Converting_db hardfork_slot

  let close t =
    match t with
    | Stable_db db ->
        Ledger.Db.close db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.close db

  let merkle_root t =
    match t with
    | Stable_db db ->
        Ledger.Db.merkle_root db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.merkle_root db

  let create ~logger ~config ~depth ?(assert_synced = false) () =
    match config with
    | Config.Stable_db_config directory_name ->
        Stable_db (Ledger.Db.create ~directory_name ~depth ())
    | Converting_db_config
        { db_config = { primary_directory; converting_directory }
        ; hardfork_slot
        } ->
        let module Converting_ledger = Ledger.Make_converting (struct
          let convert = Account.Hardfork.migrate_to_mesa ~hardfork_slot
        end) in
        let config : Converting_ledger.Config.t =
          { primary_directory; converting_directory }
        in
        Converting_db
          ( (module Converting_ledger)
          , Converting_ledger.create ~config:(In_directories config) ~logger
              ~depth ~assert_synced ()
          , hardfork_slot )

  let create_temporary ~logger ~backing_type ~depth () =
    match backing_type with
    | Config.Stable_db ->
        Stable_db (Ledger.Db.create ~depth ())
    | Converting_db hardfork_slot ->
        let module Converting_ledger = Ledger.Make_converting (struct
          let convert = Account.Hardfork.migrate_to_mesa ~hardfork_slot
        end) in
        Converting_db
          ( (module Converting_ledger)
          , Converting_ledger.create ~config:Temporary ~logger ~depth ()
          , hardfork_slot )

  let create_checkpoint t ~config () =
    match (t, config) with
    | Stable_db db, Config.Stable_db_config directory_name ->
        Stable_db (Ledger.Db.create_checkpoint db ~directory_name ())
    | ( Converting_db
          (((module Converting_ledger) as m), db, hardfork_slot_from_instance)
      , Converting_db_config
          { db_config = { primary_directory; converting_directory }
          ; hardfork_slot = hardfork_slot_from_config
          } )
      when Mina_numbers.Global_slot_since_genesis.equal
             hardfork_slot_from_instance hardfork_slot_from_config ->
        let config : Converting_ledger.Config.t =
          { primary_directory; converting_directory }
        in
        Converting_db
          ( m
          , Converting_ledger.create_checkpoint db ~config ()
          , hardfork_slot_from_instance )
    | t, config ->
        raise
          (Config.Backing_mismatch
             { backing_1 = backing_of_t t
             ; backing_2 = Config.backing_of_config config
             } )

  let make_checkpoint t ~config =
    match (t, config) with
    | Stable_db db, Config.Stable_db_config directory_name ->
        Ledger.Db.make_checkpoint db ~directory_name
    | ( Converting_db
          ((module Converting_ledger), db, hardfork_slot_from_instance)
      , Converting_db_config
          { db_config = { primary_directory; converting_directory }
          ; hardfork_slot = hardfork_slot_from_config
          } )
      when Mina_numbers.Global_slot_since_genesis.equal
             hardfork_slot_from_instance hardfork_slot_from_config ->
        let config : Converting_ledger.Config.t =
          { primary_directory; converting_directory }
        in
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
      | Stable_db _ ->
          Config.Stable_db
      | Converting_db (_, _, hardfork_slot) ->
          Converting_db hardfork_slot
    in
    let config = Config.with_directory ~backing_type ~directory_name in
    create_checkpoint t ~config ()

  (** Migrate the accounts in the ledger database [stable_db] and store them in
      [empty_hardfork_db]. The accounts are set in the target database in chunks
      so the daemon is still responsive during this operation; the daemon would
      otherwise stop everything as it hashed every account in the list. *)
  let chunked_migration ?(chunk_size = 1 lsl 6) ~hardfork_slot
      stable_locations_and_accounts empty_migrated_db =
    let open Async.Deferred.Let_syntax in
    let ledger_depth = Ledger.Hardfork_db.depth empty_migrated_db in
    let addrs_and_accounts =
      List.mapi stable_locations_and_accounts ~f:(fun i acct ->
          ( Ledger.Hardfork_db.Addr.of_int_exn ~ledger_depth i
          , Account.Hardfork.migrate_to_mesa ~hardfork_slot acct ) )
    in
    let rec set_chunks accounts =
      let%bind () = Async_unix.Scheduler.yield () in
      let chunk, accounts' = List.split_n accounts chunk_size in
      if List.is_empty chunk then return empty_migrated_db
      else (
        Ledger.Hardfork_db.set_batch_accounts empty_migrated_db chunk ;
        set_chunks accounts' )
    in
    set_chunks addrs_and_accounts

  let make_converting ~hardfork_slot t =
    let open Async.Deferred.Let_syntax in
    match t with
    | Converting_db (_, _, hardfork_slot_from_instance) ->
        (* TODO: rewrap as a Deferred.Or_error.t *)
        assert (
          Mina_numbers.Global_slot_since_genesis.equal hardfork_slot
            hardfork_slot_from_instance ) ;
        return t
    | Stable_db db ->
        let directory_name =
          Ledger.Db.get_directory db
          |> Option.value_exn
               ~message:"Invariant: database must be in a directory"
        in
        let module Converting_ledger = Ledger.Make_converting (struct
          let convert = Account.Hardfork.migrate_to_mesa ~hardfork_slot
        end) in
        let converting_config =
          Converting_ledger.Config.with_primary ~directory_name
        in
        let migrated_db =
          Ledger.Hardfork_db.create
            ~directory_name:converting_config.converting_directory
            ~depth:(Ledger.Db.depth db) ()
        in
        let%map migrated_db =
          chunked_migration ~hardfork_slot
            (Ledger.Db.to_list_sequential db)
            migrated_db
        in
        Converting_db
          ( (module Converting_ledger)
          , Converting_ledger.of_ledgers db migrated_db
          , hardfork_slot )

  let as_unmasked t =
    match t with
    | Stable_db db ->
        Ledger.Any_ledger.cast (module Ledger.Db) db
    | Converting_db ((module Converting_ledger), db, _) ->
        Ledger.Any_ledger.cast (module Converting_ledger) db

  let as_masked t = as_unmasked t |> Ledger.of_any_ledger

  let depth t =
    match t with
    | Stable_db db ->
        Ledger.Db.depth db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.depth db

  let num_accounts t =
    match t with
    | Stable_db db ->
        Ledger.Db.num_accounts db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.num_accounts db

  let merkle_path_at_addr_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.merkle_path_at_addr_exn db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.merkle_path_at_addr_exn db

  let get_inner_hash_at_addr_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.get_inner_hash_at_addr_exn db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.get_inner_hash_at_addr_exn db

  let set_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.set_all_accounts_rooted_at_exn db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.set_all_accounts_rooted_at_exn db

  let set_batch_accounts t =
    match t with
    | Stable_db db ->
        Ledger.Db.set_batch_accounts db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.set_batch_accounts db

  let get_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.get_all_accounts_rooted_at_exn db
    | Converting_db ((module Converting_ledger), db, _) ->
        Converting_ledger.get_all_accounts_rooted_at_exn db

  let unsafely_decompose_root t =
    match t with
    | Stable_db db ->
        (db, None)
    | Converting_db ((module Converting_ledger), db, _) ->
        ( Converting_ledger.primary_ledger db
        , Some (Converting_ledger.converting_ledger db) )

  let copy_reconfigured t ~config () =
    let open Deferred.Let_syntax in
    (* We must handle the transformation
       (stable|converting)->(stable|converting). Rather than handle all four
       separately, it ends up being simpler to start by asking if the two
       backings are equal or not. *)
    if
      Config.equal_backing_type (backing_of_t t)
        (Config.backing_of_config config)
    then
      (* If the src/dest backings are equal, simply checkpoint *)
      create_checkpoint t ~config () |> return
    else
      (* Otherwise, copy the stable database and then migrate if necessary *)
      let dest_root =
        Stable_db
          (Ledger.Db.create_checkpoint
             (fst (unsafely_decompose_root t))
             ~directory_name:(Config.primary_directory config)
             () )
      in
      match Config.backing_of_config config with
      | Stable_db ->
          return dest_root
      | Converting_db hardfork_slot ->
          make_converting ~hardfork_slot dest_root
end

include T
