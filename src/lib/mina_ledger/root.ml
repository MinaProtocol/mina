open Core_kernel
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

module type Any_ledger_intf =
  Merkle_ledger.Intf.Ledger.ANY
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t

module Make
    (Any_ledger : Any_ledger_intf)
    (Stable_db : Stable_db_intf
                   with module Location = Any_ledger.M.Location
                    and module Addr = Any_ledger.M.Addr) =
struct
  module Config = struct
    type t = string

    type backing_type = Stable_db

    let exists_backing = Sys.file_exists

    let with_directory ~backing_type:Stable_db ~directory_name = directory_name

    let delete_any_backing = Mina_stdlib_unix.File_system.rmrf

    let move_backing_exn ~src ~dst = Sys.rename src dst

    let primary_directory = Fn.id
  end

  module type Converting_intf =
    Merkle_ledger.Intf.Ledger.Converting.WITH_DATABASE
      with module Config = Merkle_ledger.Converting_merkle_tree
                           .With_database_config
       and module Location = Any_ledger.M.Location
       and module Addr = Stable_db.Addr
      with type root_hash := Ledger_hash.t
       and type hash := Ledger_hash.t
       and type account := Account.t
       and type key = Signature_lib.Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t

  type converting_witness =
    | T :
        (module Converting_intf with type t = 't)
        * Merkle_ledger.Converting_merkle_tree.With_database_config.t
        * 't
        -> converting_witness

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  type t = Stable_db of Stable_db.t | Converting_db of converting_witness

  let close t =
    match t with
    | Stable_db db ->
        Stable_db.close db
    | Converting_db (T ((module C), _, db)) ->
        C.close db

  let merkle_root t =
    match t with
    | Stable_db db ->
        Stable_db.merkle_root db
    | Converting_db (T ((module C), _, db)) ->
        C.merkle_root db

  let create ~config:directory_name ~depth () =
    Stable_db (Stable_db.create ~directory_name ~depth ())

  let create_temporary ~backing_type:Config.Stable_db ~depth () =
    Stable_db (Stable_db.create ~depth ())

  let create_checkpoint t ~config:directory_name () =
    match t with
    | Stable_db db ->
        Stable_db (Stable_db.create_checkpoint db ~directory_name ())
    | Converting_db (T ((module C), config, db)) ->
        let checkpointed = C.create_checkpoint db ~config () in
        Converting_db (T ((module C), config, checkpointed))

  let make_checkpoint t ~config:directory_name =
    match t with
    | Stable_db db ->
        Stable_db.make_checkpoint db ~directory_name
    | Converting_db (T ((module C), config, db)) ->
        C.make_checkpoint db ~config

  let as_unmasked t =
    match t with
    | Stable_db db ->
        Any_ledger.cast (module Stable_db) db
    | Converting_db (T ((module C), _, db)) ->
        Any_ledger.cast (module C : Any_ledger.Base_intf with type t = C.t) db

  let depth t =
    match t with
    | Stable_db db ->
        Stable_db.depth db
    | Converting_db (T ((module C), _, db)) ->
        C.depth db

  let num_accounts t =
    match t with
    | Stable_db db ->
        Stable_db.num_accounts db
    | Converting_db (T ((module C), _, db)) ->
        C.num_accounts db

  let merkle_path_at_addr_exn t =
    match t with
    | Stable_db db ->
        Stable_db.merkle_path_at_addr_exn db
    | Converting_db (T ((module C), _, db)) ->
        C.merkle_path_at_addr_exn db

  let get_inner_hash_at_addr_exn t =
    match t with
    | Stable_db db ->
        Stable_db.get_inner_hash_at_addr_exn db
    | Converting_db (T ((module C), _, db)) ->
        C.get_inner_hash_at_addr_exn db

  let set_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Stable_db.set_all_accounts_rooted_at_exn db
    | Converting_db (T ((module C), _, db)) ->
        C.set_all_accounts_rooted_at_exn db

  let set_batch_accounts t =
    match t with
    | Stable_db db ->
        Stable_db.set_batch_accounts db
    | Converting_db (T ((module C), _, db)) ->
        C.set_batch_accounts db

  let get_all_accounts_rooted_at_exn t =
    match t with
    | Stable_db db ->
        Stable_db.get_all_accounts_rooted_at_exn db
    | Converting_db (T ((module C), _, db)) ->
        C.get_all_accounts_rooted_at_exn db
end
