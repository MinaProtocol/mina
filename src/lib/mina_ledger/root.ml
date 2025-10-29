open Core
open Mina_base

module Config = struct
  type backing_type = Stable_db | Converting_db [@@deriving equal, yojson]

  (* WARN: always construct Converting_db_config with
     [with_directory ~backing_type ~directory_name], instead of manual
     creation. This is because [delete_any_backing] expect there's a
     relation between primary dir and converting dir name *)
  type t =
    | Stable_db_config of string
    | Converting_db_config of
        Merkle_ledger.Converting_merkle_tree.With_database_config.t
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

  let exists_any_backing = function
    | Stable_db_config path ->
        file_exists path
    | Converting_db_config { primary_directory; converting_directory = _ } ->
        file_exists primary_directory

  let with_directory ~backing_type ~directory_name =
    match backing_type with
    | Stable_db ->
        Stable_db_config directory_name
    | Converting_db ->
        Converting_db_config
          (Merkle_ledger.Converting_merkle_tree.With_database_config
           .with_primary ~directory_name )

  let delete_any_backing config =
    let primary, converting =
      match config with
      | Stable_db_config primary ->
          let converting =
            Merkle_ledger.Converting_merkle_tree.With_database_config
            .default_converting_directory_name primary
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

module type Intf = sig
  type t

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Ledger.Db.Addr.t

  type path = Ledger.Db.path

  val close : t -> unit

  val merkle_root : t -> root_hash

  val create_checkpoint : t -> config:Config.t -> unit -> t

  val make_checkpoint : t -> config:Config.t -> unit

  val create_checkpoint_with_directory : t -> directory_name:string -> t

  val make_converting : t -> t Async.Deferred.t

  val as_unmasked : t -> Ledger.Any_ledger.witness

  val as_masked : t -> Ledger.t

  val depth : t -> int

  val num_accounts : t -> int

  val merkle_path_at_addr_exn : t -> addr -> path

  val get_inner_hash_at_addr_exn : t -> addr -> hash

  val set_all_accounts_rooted_at_exn : t -> addr -> account list -> unit

  val set_batch_accounts : t -> (addr * account) list -> unit

  val get_all_accounts_rooted_at_exn : t -> addr -> (addr * account) list

  val unsafely_decompose_root : t -> Ledger.Db.t * Ledger.Hardfork_db.t option
end

(** An internal functor to create a converting root ledger implementation given
    a (possibly runtime-determined) account conversion function. *)
module Make (Inputs : sig
  val convert : Account.t -> Account.Hardfork.t
end) =
struct
  module Converting_ledger = Ledger.Make_converting (Inputs)

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Ledger.Db.Addr.t

  type path = Ledger.Db.path

  type t = Stable_db of Ledger.Db.t | Converting_db of Converting_ledger.t

  let backing_of_t = function
    | Stable_db _ ->
        Config.Stable_db
    | Converting_db _ ->
        Converting_db

  let close t =
    match t with
    | Stable_db db ->
        Ledger.Db.close db
    | Converting_db db ->
        Converting_ledger.close db

  let merkle_root t =
    match t with
    | Stable_db db ->
        Ledger.Db.merkle_root db
    | Converting_db db ->
        Converting_ledger.merkle_root db

  let create ~logger ~config ~depth ?(assert_synced = false) () =
    match config with
    | Config.Stable_db_config directory_name ->
        Stable_db (Ledger.Db.create ~directory_name ~depth ())
    | Converting_db_config { primary_directory; converting_directory } ->
        let config : Converting_ledger.Config.t =
          { primary_directory; converting_directory }
        in
        Converting_db
          (Converting_ledger.create ~config:(In_directories config) ~logger
             ~depth ~assert_synced () )

  let create_temporary ~logger ~backing_type ~depth () =
    match backing_type with
    | Config.Stable_db ->
        Stable_db (Ledger.Db.create ~depth ())
    | Converting_db ->
        Converting_db
          (Converting_ledger.create ~config:Temporary ~logger ~depth ())

  let create_checkpoint t ~config () =
    match (t, config) with
    | Stable_db db, Config.Stable_db_config directory_name ->
        Stable_db (Ledger.Db.create_checkpoint db ~directory_name ())
    | ( Converting_db db
      , Converting_db_config { primary_directory; converting_directory } ) ->
        let config : Converting_ledger.Config.t =
          { primary_directory; converting_directory }
        in
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
        Ledger.Db.make_checkpoint db ~directory_name
    | ( Converting_db db
      , Converting_db_config { primary_directory; converting_directory } ) ->
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
    let ledger_depth = Ledger.Hardfork_db.depth empty_migrated_db in
    let addrs_and_accounts =
      List.mapi stable_locations_and_accounts ~f:(fun i acct ->
          ( Ledger.Hardfork_db.Addr.of_int_exn ~ledger_depth i
          , Account.Hardfork.of_stable acct ) )
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

  let make_converting t =
    let open Async.Deferred.Let_syntax in
    match t with
    | Converting_db _db ->
        return t
    | Stable_db db ->
        let directory_name =
          Ledger.Db.get_directory db
          |> Option.value_exn
               ~message:"Invariant: database must be in a directory"
        in
        let converting_config =
          Converting_ledger.Config.with_primary ~directory_name
        in
        let migrated_db =
          Ledger.Hardfork_db.create
            ~directory_name:converting_config.converting_directory
            ~depth:(Ledger.Db.depth db) ()
        in
        let%map migrated_db =
          chunked_migration (Ledger.Db.to_list_sequential db) migrated_db
        in
        Converting_db (Converting_ledger.of_ledgers db migrated_db)

  let as_unmasked t =
    match t with
    | Stable_db db ->
        Ledger.Any_ledger.cast (module Ledger.Db) db
    | Converting_db db ->
        Ledger.Any_ledger.cast (module Converting_ledger) db

  let as_masked t = as_unmasked t |> Ledger.of_any_ledger

  let depth t =
    match t with
    | Stable_db db ->
        Ledger.Db.depth db
    | Converting_db db ->
        Converting_ledger.depth db

  let num_accounts t =
    match t with
    | Stable_db db ->
        Ledger.Db.num_accounts db
    | Converting_db db ->
        Converting_ledger.depth db

  let merkle_path_at_addr_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.merkle_path_at_addr_exn db
    | Converting_db db ->
        Converting_ledger.merkle_path_at_addr_exn db

  let get_inner_hash_at_addr_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.get_inner_hash_at_addr_exn db
    | Converting_db db ->
        Converting_ledger.get_inner_hash_at_addr_exn db

  let set_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.set_all_accounts_rooted_at_exn db
    | Converting_db db ->
        Converting_ledger.set_all_accounts_rooted_at_exn db

  let set_batch_accounts t =
    match t with
    | Stable_db db ->
        Ledger.Db.set_batch_accounts db
    | Converting_db db ->
        Converting_ledger.set_batch_accounts db

  let get_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Ledger.Db.get_all_accounts_rooted_at_exn db
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

(** A temporary root ledger implementation that does not take the vesting
    parameter adjustment into account. In future this will be removed, once the
    account conversion method is modified to be dependent on the hard fork stop
    slots and genesis delta. *)
module Compat = Make (struct
  let convert = Account.Hardfork.of_stable
end)

(** A wrapper for specific root ledger implementations, using the same technique
    as [Ledger.Any_ledger] implementation. Concrete root ledgers can be cast to
    an [Any_root.witness] and then passed to other components that do not need
    to know how the root ledger is implemented.

    The [Any_root] is exposed as the root ledger implementation because the
    [Root.create] functions need the ability to select between one of a fixed
    number of root implementations at runtime.
*)
module Any_root = struct
  type witness = T : (module Intf with type t = 't) * 't -> witness

  let cast (m : (module Intf with type t = 'a)) (t : 'a) = T (m, t)

  module M : Intf with type t = witness = struct
    type t = witness

    type root_hash = Ledger_hash.t

    type hash = Ledger_hash.t

    type account = Account.t

    type addr = Ledger.Db.Addr.t

    type path = Ledger.Db.path

    let close (T ((module Root), t)) = Root.close t

    let merkle_root (T ((module Root), t)) = Root.merkle_root t

    let create_checkpoint (T ((module Root), t)) ~config () =
      T ((module Root), Root.create_checkpoint t ~config ())

    let make_checkpoint (T ((module Root), t)) ~config =
      Root.make_checkpoint t ~config

    let create_checkpoint_with_directory (T ((module Root), t)) ~directory_name
        =
      T ((module Root), Root.create_checkpoint_with_directory t ~directory_name)

    let make_converting (T ((module Root), t)) =
      let open Async.Deferred.Let_syntax in
      let%map t' = Root.make_converting t in
      T ((module Root), t')

    let as_unmasked (T ((module Root), t)) = Root.as_unmasked t

    let as_masked (T ((module Root), t)) = Root.as_masked t

    let depth (T ((module Root), t)) = Root.depth t

    let num_accounts (T ((module Root), t)) = Root.num_accounts t

    let merkle_path_at_addr_exn (T ((module Root), t)) =
      Root.merkle_path_at_addr_exn t

    let get_inner_hash_at_addr_exn (T ((module Root), t)) =
      Root.get_inner_hash_at_addr_exn t

    let set_all_accounts_rooted_at_exn (T ((module Root), t)) =
      Root.set_all_accounts_rooted_at_exn t

    let set_batch_accounts (T ((module Root), t)) = Root.set_batch_accounts t

    let get_all_accounts_rooted_at_exn (T ((module Root), t)) =
      Root.get_all_accounts_rooted_at_exn t

    let unsafely_decompose_root (T ((module Root), t)) =
      Root.unsafely_decompose_root t
  end
end

include Any_root.M

let create ~logger ~config ~depth ?(assert_synced = false) () =
  let r = Compat.create ~logger ~config ~depth ~assert_synced () in
  Any_root.cast (module Compat) r

let create_temporary ~logger ~backing_type ~depth () =
  let r = Compat.create_temporary ~logger ~backing_type ~depth () in
  Any_root.cast (module Compat) r
