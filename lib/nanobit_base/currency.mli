open Core
open Snark_params.Tick

module type Basic = sig
  type t
  [@@deriving sexp, compare, eq, hash]

  module Stable : sig
    module V1 : sig
      type nonrec t = t
      [@@deriving bin_io, sexp, compare, eq, hash]
    end
  end

  include Bits_intf.S with type t := t

  val length : int

  val zero : t

  val of_string : string -> t
  val to_string : t -> string

  type var
  val typ : (var, t) Typ.t

  val of_int : int -> t

  val var_of_t : t -> var

  val var_to_bits : var -> Boolean.var Bitstring.Lsb_first.t
end

module type Arithmetic_intf = sig
  type t
  val add : t -> t -> t option
  val sub : t -> t -> t option
  val (+) : t -> t -> t option
  val (-) : t -> t -> t option
end

module type Checked_arithmetic_intf = sig
  type var
  val add : var -> var -> (var, _) Checked.t
  val sub : var -> var -> (var, _) Checked.t
  val (+) : var -> var -> (var, _) Checked.t
  val (-) : var -> var -> (var, _) Checked.t
end

module Fee : sig
  include Basic
  include Arithmetic_intf with type t := t
  module Checked : Checked_arithmetic_intf with type var := var
end

module Amount : sig
  include Basic
  include Arithmetic_intf with type t := t

  type amount_var = var

  val of_fee : Fee.t -> t

  val add_fee : t -> Fee.t -> t option

  module Signed : sig
    type ('magnitude, 'sgn) t_

    val length : int

    val create : magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) t_

    type nonrec t = (t, Sgn.t) t_
    [@@deriving bin_io]

    type nonrec var = (var, Sgn.var) t_
    val typ : (var, t) Typ.t

    val zero : t

    val fold : t -> init:'acc -> f:('acc -> bool -> 'acc) -> 'acc

    val add : t -> t -> t option
    val (+) : t -> t -> t option

    module Checked : sig
      val to_bits : var -> Boolean.var list

      val add : var -> var -> (var, _) Checked.t
      val (+) : var -> var -> (var, _) Checked.t

      val cswap
        : Boolean.var
        -> (amount_var, Sgn.t) t_ * (amount_var, Sgn.t) t_
        -> (var * var, _) Checked.t
    end
  end

  module Checked : sig
    include Checked_arithmetic_intf with type var := var

    val add_signed : var -> Signed.var -> (var, _) Checked.t

    val of_fee : Fee.var -> var

    val add_fee : var -> Fee.var -> (var, _) Checked.t
  end
end

module Balance : sig
  include Basic
  val add_amount : t -> Amount.t -> t option
  val sub_amount : t -> Amount.t -> t option
  val (+) : t -> Amount.t -> t option
  val (-) : t -> Amount.t -> t option

  module Checked : sig
    val add_signed_amount : var -> Amount.Signed.var -> (var, _) Checked.t
    val add_amount : var -> Amount.var -> (var, _) Checked.t
    val sub_amount : var -> Amount.var -> (var, _) Checked.t
    val (+) : var -> Amount.var -> (var, _) Checked.t
    val (-) : var -> Amount.var -> (var, _) Checked.t
  end
end
