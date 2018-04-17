open Core
open Ledger

module Hash = struct

  type hash = Md5.t [@@deriving sexp, hash, compare, bin_io]
  type account = int [@@deriving sexp, bin_io]

  (* to prevent pre-image attack,
   * important impossible to create an account such that (merge a b = hash_account account) *)

  let hash_account account = Md5.digest_string ("0" ^ (Sexp.to_string ([%sexp_of: account] account)))
  ;;

  let empty_hash = Md5.digest_string ""
  ;;


  let merge a b =  Md5.digest_string ((Md5.to_hex a) ^ (Md5.to_hex b))
  ;;

end

module Max_depth = struct
  let max_depth = 64
end

module Little_max_depth = struct
  let max_depth = 4
end

module Key = struct
  module T = struct
    type t = string [@@deriving sexp, compare, hash, bin_io]
    type key = t [@@deriving sexp, bin_io]
  end
  include T 
  include Hashable.Make_binable(T)
end

include Ledger.Make(Hash)(Max_depth)(Key)

module Little_ledger = Ledger.Make(Hash)(Little_max_depth)(Key)
