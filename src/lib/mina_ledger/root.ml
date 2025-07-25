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
  type root_hash = Ledger_hash.t

  type hash = Ledger_hash.t

  type account = Account.t

  type addr = Stable_db.Addr.t

  type path = Stable_db.path

  type t = Stable_db of Stable_db.t

  let close t = match t with Stable_db db -> Stable_db.close db

  let merkle_root t = match t with Stable_db db -> Stable_db.merkle_root db

  let create_single ?directory_name ~depth () =
    Stable_db (Stable_db.create ?directory_name ~depth ())

  let create_checkpoint t ~directory_name () =
    match t with
    | Stable_db db ->
        Stable_db (Stable_db.create_checkpoint db ~directory_name ())

  let make_checkpoint t ~directory_name =
    match t with Stable_db db -> Stable_db.make_checkpoint db ~directory_name

  let as_unmasked t =
    match t with Stable_db db -> Any_ledger.cast (module Stable_db) db

  let transfer_accounts_with ~stable ~src ~dest =
    match (src, dest) with
    | Stable_db db1, Stable_db db2 ->
        stable ~src:db1 ~dest:db2 |> Or_error.map ~f:(fun x -> Stable_db x)

  let depth t = match t with Stable_db db -> Stable_db.depth db

  let num_accounts t = match t with Stable_db db -> Stable_db.num_accounts db

  let merkle_path_at_addr_exn t =
    match t with Stable_db db -> Stable_db.merkle_path_at_addr_exn db

  let get_inner_hash_at_addr_exn t =
    match t with Stable_db db -> Stable_db.get_inner_hash_at_addr_exn db

  let set_all_accounts_rooted_at_exn t =
    match t with Stable_db db -> Stable_db.set_all_accounts_rooted_at_exn db

  let set_batch_accounts t =
    match t with Stable_db db -> Stable_db.set_batch_accounts db

  let get_all_accounts_rooted_at_exn t =
    match t with Stable_db db -> Stable_db.get_all_accounts_rooted_at_exn db
end
