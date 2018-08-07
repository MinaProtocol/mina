open Core
open Ledger

module Account = struct
  type t = {balance: int; key: string} [@@deriving sexp, eq, bin_io]

  let public_key {key} = key

  let balance {balance} = balance
end

module Hash = struct
  type hash = Md5.t [@@deriving sexp, hash, compare, bin_io, eq]

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account =
    Md5.digest_string ("0" ^ Sexp.to_string ([%sexp_of : Account.t] account))

  let empty_hash = Md5.digest_string ""

  let merge ~height a b =
    let res =
      Md5.digest_string
        (sprintf "test_ledger_%d:" height ^ Md5.to_hex a ^ Md5.to_hex b)
    in
    res

  (* Printf.printf "merge(%d, %s, %s) = %s\n" height (Sexp.to_string_hum (sexp_of_hash a)) (Sexp.to_string_hum (sexp_of_hash b)) (Sexp.to_string_hum (sexp_of_hash res)); res *)
end

module Key = struct
  module T = struct
    type t = string [@@deriving sexp, compare, hash, bin_io]

    type key = t [@@deriving sexp, bin_io]
  end

  let empty = ""

  include T
  include Hashable.Make_binable (T)
end

module Make = Ledger.Make (Key) (Account) (Hash)
