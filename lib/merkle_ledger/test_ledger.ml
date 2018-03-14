open Core
open Ledger

module Hash = struct

  type hash = Md5.t [@@deriving sexp]
  type account = int [@@deriving sexp]

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account = Md5.digest_string ("0" ^ (Sexp.to_string ([%sexp_of: account] account)))
  ;;

  let hash_unit = Md5.digest_string ""
  ;;

  let merge a b =  Md5.digest_string ((Md5.to_hex a) ^ (Md5.to_hex b))
  ;;
  
end

module Key = struct
  module T = struct
    type t = string [@@deriving sexp, compare, hash]
    type key = t [@@deriving sexp]
  end
  include T 
  include Hashable.Make(T)
end

include Ledger.Make(Hash)(Key)
