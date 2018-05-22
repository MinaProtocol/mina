open Core
open Snark_params
open Tick

type t = Field.t * Field.t
[@@deriving sexp, eq, compare, hash]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp, compare, eq, hash]
  end
end

type var = Field.var * Field.var

val typ_unchecked : (var, t) Typ.t

val typ : (var, t) Typ.t

val of_private_key : Private_key.t -> t

module Compressed : sig
  type ('field, 'boolean) t_ =
    { x      : 'field
    ; is_odd : 'boolean
    }

  type t = (Field.t, bool) t_ [@@deriving bin_io, sexp, eq, compare, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving sexp, bin_io, eq, compare, hash]
    end
  end

  type var = (Field.var, Boolean.var) t_
  val typ : (var, t) Typ.t

  include Hashable.S_binable with type t := t

  val fold : t -> init:'acc -> f:('acc -> bool -> 'acc) -> 'acc
  val to_bits : t -> bool list

  val var_to_bits : var -> (Boolean.var list, _) Checked.t
  val assert_equal : var -> var -> (unit, _) Checked.t
end

val of_bigstring : Bigstring.t -> t Or_error.t
val to_bigstring : t -> Bigstring.t

val compress : t -> Compressed.t
val decompress : Compressed.t -> t option
val decompress_exn : Compressed.t -> t

val compress_var : var -> (Compressed.var, _) Checked.t
val decompress_var : Compressed.var -> (var, _) Checked.t
