open Core_kernel
open Mina_base
open Merkle_ledger

module type Stable_db_intf =
  Intf.Ledger.DATABASE
    with type account := Account.t
     and type key := Signature_lib.Public_key.Compressed.t
     and type token_id := Token_id.t
     and type token_id_set := Token_id.Set.t
     and type account_id := Account_id.t
     and type account_id_set := Account_id.Set.t
     and type hash := Ledger_hash.t
     and type root_hash := Ledger_hash.t

module type Any_ledger_intf =
  Intf.Ledger.ANY
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
  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  module type Converting_intf =
    Intf.Ledger.Converting.WITH_DATABASE
      with module Config = Converting_merkle_tree.With_database_config
       and module Location = Any_ledger.M.Location
       and module Addr = Stable_db.Addr
      with type root_hash = hash
       and type hash = hash
       and type account = account
       and type key = Signature_lib.Public_key.Compressed.t
       and type token_id := Token_id.t
       and type token_id_set := Token_id.Set.t
       and type account_id := Account_id.t
       and type account_id_set := Account_id.Set.t

  type converting_witness =
    | T :
        (module Converting_intf with type t = 't)
        * Converting_merkle_tree.With_database_config.t
        * 't
        -> converting_witness

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

  let create_single ?directory_name ~depth () =
    Stable_db (Stable_db.create ?directory_name ~depth ())

  let create_checkpoint t ~directory_name () =
    match t with
    | Stable_db db ->
        Stable_db (Stable_db.create_checkpoint db ~directory_name ())
    | Converting_db (T ((module C), config, db)) ->
        let checkpointed = C.create_checkpoint db ~config () in
        Converting_db (T ((module C), config, checkpointed))

  let make_checkpoint t ~directory_name =
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

  let transfer_accounts_with ~stable ~src ~dest =
    match (src, dest) with
    | Stable_db db1, Stable_db db2 ->
        stable ~src:db1 ~dest:db2 |> Or_error.map ~f:(fun x -> Stable_db x)
    | Converting_db _, Converting_db _ ->
        (* NOTE: Waiting for implementation of
           https://www.notion.so/o1labs/Add-transfer_accounts_with-to-Converting_merkle_tree-23fe79b1f910806da69eda07d1e75e87*)
        failwith "Unimplemented"
    | _ ->
        failwith "Unimplemented"

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
