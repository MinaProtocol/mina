open Core
open Ledger

module Account = struct
  type t = int [@@deriving sexp, eq, bin_io]
end

module Hash = struct
  type hash = Md5.t [@@deriving sexp, hash, compare, bin_io]

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account =
    Md5.digest_string ("0" ^ Sexp.to_string ([%sexp_of : Account.t] account))

  let empty_hash = Md5.digest_string ""

  let merge ~height a b =
    Md5.digest_string
      (sprintf "test_ledger_%d:" height ^ Md5.to_hex a ^ Md5.to_hex b)
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

module Make = Ledger.Make (Account) (Hash) (Key)
