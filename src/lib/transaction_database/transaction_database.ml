open Coda_base
open Core
open Signature_lib

(* TODO: This database should be optimized to query an individual transaction quickly. Also, it can technically take a long time to make a row update since we read a list of transactions from a user in the database and we just append the transaction into the list and then write that to the database *)
module Transaction_list = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = Transaction.Stable.V1.t Non_empty_list.Stable.V1.t
        [@@deriving bin_io, version {unnumbered}]
      end

      include T
    end

    module Latest = V1
  end
end

module Database =
  Rocksdb.Serializable.Make
    (Transaction.Stable.V1)
    (Public_key.Compressed.Stable.V1)

type cache =
  { user_transactions: Transaction.t list Public_key.Compressed.Table.t
  ; all_transactions: Transaction.Hash_set.t }

type t = {database: Database.t; cache: cache}

let create ?directory_name () =
  let directory =
    match directory_name with
    | None ->
        Uuid.to_string (Uuid_unix.create ())
    | Some name ->
        name
  in
  { database= Database.create ~directory
  ; cache=
      { user_transactions= Public_key.Compressed.Table.create ()
      ; all_transactions= Transaction.Hash_set.create () } }

(* TODO: make load function #2333 *)

let close {database; _} = Database.close database

let add t (public_key : Public_key.Compressed.t) transaction =
  match Hash_set.strict_add t.cache.all_transactions transaction with
  | Error _ ->
      ()
  | Ok () ->
      Database.set t.database ~key:transaction ~data:public_key ;
      Hashtbl.add_multi t.cache.user_transactions ~key:public_key
        ~data:transaction

let get_transactions {cache= {user_transactions; _}; _} public_key =
  let open Option.Monad_infix in
  Hashtbl.find user_transactions public_key >>= Non_empty_list.of_list_opt
