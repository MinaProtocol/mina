open Core
open Snark_params
open Tick
open Fold_lib
open Tuple_lib

module type S = sig
  type t [@@deriving sexp, bin_io, eq, compare, hash]

  type var = Boolean.var list

  val length_in_bits : int

  val typ : (var, t) Typ.t

  val fold : t -> bool Triple.t Fold.t

  val length_in_triples : int

  val var_of_t : t -> var

  val to_bits : t -> bool list

  val to_string : t -> string

  val of_string : string -> t

  val of_bits : bool list -> t

  val dummy : t

  val create : string -> t
end

(*module Memo : Payment_memo.S = struct 
  include Sha256.Digest
  let create = Sha256.digest_string
  let dummy = Sha256.dummy
end*)

(*module Make_memo (Input : S)
= struct

  module 
  type t = S.t [@@deriving bin_io, eq, sexp, hash]
   
  (*let of_string s = 
    let t = Memoable.of_string s in
    if Memoable.bin_size_t t > Constants.max_length
    then Or_error.error_string *)
    
  let to_string = Memoable.to_string

  let length = Memoable.length

end*)
