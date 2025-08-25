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

module type Unstable_db_intf =
  Merkle_ledger.Intf.Ledger.DATABASE
    with type account := Account.Unstable.t
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

let primary_suffix = "PRIMARY"

let converting_suffix = "CONVERTED"

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
     and type converted_account := Account.Unstable.t

module Make
    (Any_ledger : Any_ledger_intf)
    (Stable_db : Stable_db_intf
                   with module Location = Any_ledger.M.Location
                    and module Addr = Any_ledger.M.Addr)
    (Unstable_db : Unstable_db_intf
                     with module Location = Any_ledger.M.Location
                      and module Addr = Any_ledger.M.Addr)
    (Converting_ledger : Converting_ledger_intf
                           with module Location = Any_ledger.M.Location
                            and module Addr = Any_ledger.M.Addr
                           with type primary_ledger = Stable_db.t
                            and type converting_ledger = Unstable_db.t) =
struct
  module Config = struct
    type backing_type = Stable_db | Converting_db [@@deriving equal]

    type t = { top_directory : string; backing_type : backing_type }

    let exists_backing { top_directory; backing_type } =
      let file_exists path =
        Sys.file_exists path |> [%equal: [ `No | `Unknown | `Yes ]] `Yes
      in
      match backing_type with
      | Stable_db ->
          file_exists top_directory
      | Converting_db ->
          file_exists (top_directory ^/ primary_suffix)
          && file_exists (top_directory ^/ converting_suffix)

    (* TODO: we should be able to tell backing type of a root just by looking at
       the dir structure, maybe it can be utilized to simplify our code *)
    let with_directory ~backing_type ~directory_name =
      { top_directory = directory_name; backing_type }

    let delete_any_backing { top_directory; _ } =
      Mina_stdlib_unix.File_system.rmrf top_directory

    exception
      Backing_mismatch of { backing_1 : backing_type; backing_2 : backing_type }

    let move_backing_exn
        ~src:{ top_directory = top_src; backing_type = backing_src }
        ~dst:{ top_directory = top_dst; backing_type = backing_dst } =
      if equal_backing_type backing_src backing_dst then
        Sys.rename top_src top_dst
      else
        raise
          (Backing_mismatch { backing_1 = backing_src; backing_2 = backing_dst })

    let primary_directory { top_directory; backing_type } =
      match backing_type with
      | Stable_db ->
          top_directory
      | Converting_db ->
          top_directory ^/ primary_suffix
  end

  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  type t = Stable_db of Stable_db.t | Converting_db of Converting_ledger.t

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

  let prepare_converting_dirs top_directory =
    let primary_directory = top_directory ^/ primary_suffix in
    let converting_directory = top_directory ^/ converting_suffix in
    let () = Unix.mkdir primary_directory in
    let () = Unix.mkdir converting_directory in
    Converting_ledger.Config.{ primary_directory; converting_directory }

  let create ~logger ~config:Config.{ top_directory; backing_type } ~depth () =
    match backing_type with
    | Stable_db ->
        Stable_db (Stable_db.create ~directory_name:top_directory ~depth ())
    | Converting_db ->
        let config = prepare_converting_dirs top_directory in
        Converting_db
          (Converting_ledger.create ~config:(In_directories config) ~logger
             ~depth () )

  let create_temporary ~logger ~backing_type ~depth () =
    match backing_type with
    | Config.Stable_db ->
        Stable_db (Stable_db.create ~depth ())
    | Converting_db ->
        Converting_db
          (Converting_ledger.create ~config:Temporary ~logger ~depth ())

  let create_checkpoint t ~config:Config.{ top_directory; backing_type } () =
    match t with
    | Stable_db db ->
        if not Config.(equal_backing_type backing_type Stable_db) then
          raise
            (Config.Backing_mismatch
               { backing_1 = Stable_db; backing_2 = backing_type } )
        else
          Stable_db
            (Stable_db.create_checkpoint db ~directory_name:top_directory ())
    | Converting_db db ->
        if not Config.(equal_backing_type backing_type Converting_db) then
          raise
            (Config.Backing_mismatch
               { backing_1 = Converting_db; backing_2 = backing_type } )
        else
          let config = prepare_converting_dirs top_directory in
          Converting_db (Converting_ledger.create_checkpoint db ~config ())

  let make_checkpoint t ~config:Config.{ top_directory; backing_type } =
    match t with
    | Stable_db db ->
        if not Config.(equal_backing_type backing_type Stable_db) then
          raise
            (Config.Backing_mismatch
               { backing_1 = Stable_db; backing_2 = backing_type } )
        else Stable_db.make_checkpoint db ~directory_name:top_directory
    | Converting_db db ->
        if not Config.(equal_backing_type backing_type Converting_db) then
          raise
            (Config.Backing_mismatch
               { backing_1 = Converting_db; backing_2 = backing_type } )
        else
          let config = prepare_converting_dirs top_directory in
          Converting_ledger.make_checkpoint db ~config

  let as_unmasked t =
    match t with
    | Stable_db db ->
        Any_ledger.cast (module Stable_db) db
    | Converting_db db ->
        Any_ledger.cast (module Converting_ledger) db

  let transfer_accounts_with ~stable ~src ~dest =
    match (src, dest) with
    | Stable_db db1, Stable_db db2 ->
        stable ~src:db1 ~dest:db2 |> Or_error.map ~f:(fun x -> Stable_db x)
    | _ ->
        failwith "TODO: this function should be removed"

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
end
