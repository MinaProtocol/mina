open Core
open Unsigned

module Balance = struct
  include UInt64
  include Binable.Of_stringable (UInt64)

  let equal x y = UInt64.compare x y = 0
end

module Account = struct
  type t =
    { public_key: string
    ; balance: Balance.t
           [@printer
             fun fmt balance ->
               Format.pp_print_string fmt (Balance.to_string balance)] }
  [@@deriving bin_io, eq, show, fields]

  let sexp_of_t {public_key; balance} =
    [%sexp_of: string * string] (public_key, Balance.to_string balance)

  let t_of_sexp sexp =
    let public_key, string_balance = [%of_sexp: string * string] sexp in
    let balance = Balance.of_string string_balance in
    {public_key; balance}

  let set_balance {public_key; _} balance = {public_key; balance}

  let create public_key balance = {public_key; balance= UInt64.of_int balance}

  let empty = {public_key= ""; balance= Balance.zero}

  let gen =
    let open Quickcheck.Let_syntax in
    let%bind public_key = String.gen in
    let%map int_balance = Int.gen in
    let nat_balance = abs int_balance in
    let balance = Balance.of_int nat_balance in
    {public_key; balance}
end

module Hash = struct
  type t = Md5.t [@@deriving sexp, hash, compare, bin_io, eq]

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account = Md5.digest_string ("0" ^ Account.show account)

  let merge ~height a b =
    let res =
      Md5.digest_string
        (sprintf "test_ledger_%d:" height ^ Md5.to_hex a ^ Md5.to_hex b)
    in
    res

  let empty_account = hash_account Account.empty
end

module Intf = Merkle_ledger.Intf

module In_memory_kvdb : Intf.Key_value_database = struct
  type t = (string, Bigstring.t) Hashtbl.t

  let create ~directory:_ = Hashtbl.create (module String)

  let destroy _ = ()

  let get tbl ~key = Hashtbl.find tbl (Bigstring.to_string key)

  let set tbl ~key ~data = Hashtbl.set tbl ~key:(Bigstring.to_string key) ~data

  let set_batch tbl ~key_data_pairs =
    List.iter key_data_pairs ~f:(fun (key, data) -> set tbl ~key ~data)

  let delete tbl ~key = Hashtbl.remove tbl (Bigstring.to_string key)

  let copy tbl = Hashtbl.copy tbl
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

  let copy stack = ref !stack
end

module Storage_locations : Intf.Storage_locations = struct
  (* TODO: The names of these values should be dynamically generated per test run*)
  let stack_db_file = ""

  let key_value_db_dir = ""
end

module Key = struct
  module T = struct
    type t = string [@@deriving sexp, compare, hash, bin_io]
  end

  let empty = ""

  let to_string = Fn.id

  include T
  include Hashable.Make_binable (T)
end
