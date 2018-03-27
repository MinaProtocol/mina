open Core
open Snark_params.Tick

module type Basic = sig
  type t
  [@@deriving sexp, compare, eq]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, eq]
    end
  end

  include Bits_intf.S with type t := t

  val zero : t

  val of_string : string -> t
  val to_string : t -> string

  type var
  val typ : (var, t) Typ.t

  val of_int : int -> t

  val var_of_t : t -> var

  val var_to_bits : var -> Boolean.var list
end

module type S = sig
  include Basic

  val add : t -> t -> t option
  val sub : t -> t -> t option
  val (+) : t -> t -> t option
  val (-) : t -> t -> t option

  module Checked : sig
    val add : var -> var -> (var, _) Checked.t
    val sub : var -> var -> (var, _) Checked.t
    val (+) : var -> var -> (var, _) Checked.t
    val (-) : var -> var -> (var, _) Checked.t
  end
end

module Amount : S

module Fee : S

module Balance : sig
  include Basic
  val add_amount : t -> Amount.t -> t option
  val sub_amount : t -> Amount.t -> t option
  val (+) : t -> Amount.t -> t option
  val (-) : t -> Amount.t -> t option

  module Checked : sig
    val add_amount : var -> Amount.var -> (var, _) Checked.t
    val sub_amount : var -> Amount.var -> (var, _) Checked.t
    val (+) : var -> Amount.var -> (var, _) Checked.t
    val (-) : var -> Amount.var -> (var, _) Checked.t
  end
end
