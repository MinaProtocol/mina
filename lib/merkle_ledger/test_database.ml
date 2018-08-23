open Core
open Unsigned

module Balance = struct
  include UInt64
  include Binable.Of_stringable (UInt64)

  let equal x y = UInt64.compare x y = 0
end

module Account : sig
  include Intf.Account with type balance := Balance.t

  val gen : t Quickcheck.Generator.t
end = struct
  type t = {public_key: string; balance: Balance.t} [@@deriving bin_io, eq]

  let empty = {public_key= ""; balance= Balance.zero}

  let balance {balance; _} = balance

  let set_balance {public_key; _} balance = {public_key; balance}

  let public_key {public_key; _} = public_key

  let gen =
    let open Quickcheck.Let_syntax in
    let%bind public_key = String.gen in
    let%map int_balance = Int.gen in
    let nat_balance = abs int_balance in
    let balance = Balance.of_int nat_balance in
    {public_key; balance}
end

module Hash = struct
  type t = int [@@deriving sexp, hash, compare, bin_io, eq]

  let empty = 0

  let merge ~height left right = Hashtbl.hash (height, left, right)

  let hash_account : Account.t -> t = Hashtbl.hash
end

module In_memory_kvdb : Intf.Key_value_database = struct
  type t = (string, Bigstring.t) Hashtbl.t

  let create ~directory:_ = Hashtbl.create (module String)

  let destroy _ = ()

  let get tbl ~key = Hashtbl.find tbl (Bigstring.to_string key)

  let set tbl ~key ~data = Hashtbl.set tbl ~key:(Bigstring.to_string key) ~data

  let delete tbl ~key = Hashtbl.remove tbl (Bigstring.to_string key)
end

module In_memory_sdb : Intf.Stack_database = struct
  type t = Bigstring.t list ref

  let create ~filename:_ = ref []

  let destroy _ = ()

  let push ls v = ls := v :: !ls

  let pop ls =
    match !ls with
    | [] -> None
    | h :: t ->
        ls := t ;
        Some h

  let length ls = List.length !ls
end

module Make (Depth : Intf.Depth) = struct
  module MT =
    Database.Make (Balance) (Account) (Hash) (Depth) (In_memory_kvdb)
      (In_memory_sdb)
  include MT
end
