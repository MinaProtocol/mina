open Snark_params
open Tick
open Tuple_lib

exception Invalid_user_memo_length

exception Too_long_digestible_string

type t [@@deriving sexp, eq, compare, hash, yojson]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp, eq, compare, hash, yojson, version]
  end

  module Latest = V1
end

module Checked : sig
  type unchecked = t

  type t = private Boolean.var array

  val to_triples : t -> Boolean.var Triple.t list

  val constant : unchecked -> t
end

val dummy : t

val to_string : t -> string

val of_string : string -> t

val max_digestible_string_length : int

(** create a memo by digesting a string; raises [Too_long_digestible_string] if 
    length exceeds [max_digestible_string_length]
 *)
val create_by_digesting_string_exn : string -> t

(** create a memo from bytes of length exactly 32;
    raise [Invalid_user_memo_length] for any other length 
 *)
val create_from_bytes32_exn : bytes -> t

(** create a memo from a string of length exactly 32;
    raise [Invalid_user_memo_length] for any other length 
 *)
val create_from_string32_exn : string -> t

(** convert a memo to a fold of boolean triples 
 *)
val fold : t -> bool Tuple_lib.Triple.t Fold_lib.Fold.t

(** number of triples to represent a memo
 *)
val length_in_triples : int

(** typ representation *)
val typ : (Checked.t, t) Curve_choice.Tick0.Typ.t
