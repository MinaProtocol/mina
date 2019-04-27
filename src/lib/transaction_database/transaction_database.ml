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

type t =
  {database: Database.t; cache: Transaction.t Public_key.Compressed.Table.t}

let create ?directory_name () =
  let directory =
    match directory_name with
    | None ->
        Uuid.to_string (Uuid_unix.create ())
    | Some name ->
        name
  in
  { database= Database.create ~directory
  ; cache= Public_key.Compressed.Table.create () }

let close = Database.close

let add t (public_key : Public_key.Compressed.t) transaction =
  match Database.get t ~key:public_key with
  | Some stored_transactions ->
      Database.set t ~key:public_key
        ~data:(Non_empty_list.cons transaction stored_transactions)
  | None ->
      Database.set t ~key:public_key ~data:(Non_empty_list.init transaction [])

let get_transactions t public_key = Database.get t ~key:public_key
