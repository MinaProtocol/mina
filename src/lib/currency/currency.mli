open Core
open Snark_params.Tick
open Snark_bits
open Fold_lib
open Tuple_lib

type uint64 = Unsigned.uint64

module type Basic = sig
  type t [@@deriving bin_io, sexp, compare, hash]

  include Comparable.S with type t := t

  val gen : t Quickcheck.Generator.t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare, eq, hash]
    end
  end

  include Bits_intf.S with type t := t

  val fold : t -> bool Triple.t Fold.t

  val length_in_triples : int

  val zero : t

  val of_string : string -> t

  val to_string : t -> string

  type var

  val typ : (var, t) Typ.t

  val of_int : int -> t

  val to_int : t -> int

  val to_uint64 : t -> uint64

  val of_uint64 : uint64 -> t

  val var_of_t : t -> var

  val var_to_triples : var -> Boolean.var Triple.t list
end

module type Arithmetic_intf = sig
  type t

  val add : t -> t -> t option

  val sub : t -> t -> t option

  val ( + ) : t -> t -> t option

  val ( - ) : t -> t -> t option
end

module type Checked_arithmetic_intf = sig
  type t

  type var

  type signed_var

  val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

  val if_value : Boolean.var -> then_:t -> else_:t -> var

  val add : var -> var -> (var, _) Checked.t

  val sub : var -> var -> (var, _) Checked.t

  val sub_flagged :
    var -> var -> (var * [`Underflow of Boolean.var], _) Checked.t

  val ( + ) : var -> var -> (var, _) Checked.t

  val ( - ) : var -> var -> (var, _) Checked.t

  val add_signed : var -> signed_var -> (var, _) Checked.t
end

module type Signed_intf = sig
  type magnitude

  type magnitude_var

  type ('magnitude, 'sgn) t_

  type t = (magnitude, Sgn.t) t_ [@@deriving sexp, hash, bin_io, compare, eq]

  val gen : t Quickcheck.Generator.t

  module Stable : sig
    module V1 : sig
      type nonrec ('magnitude, 'sgn) t_ = ('magnitude, 'sgn) t_

      type nonrec t = t [@@deriving bin_io, sexp, hash, compare, eq]
    end
  end

  val length_in_triples : int

  val create : magnitude:'magnitude -> sgn:'sgn -> ('magnitude, 'sgn) t_

  val sgn : t -> Sgn.t

  val magnitude : t -> magnitude

  type nonrec var = (magnitude_var, Sgn.var) t_

  val typ : (var, t) Typ.t

  val zero : t

  val fold : t -> bool Triple.t Fold.t

  val to_triples : t -> bool Triple.t list

  val add : t -> t -> t option

  val ( + ) : t -> t -> t option

  val negate : t -> t

  val of_unsigned : magnitude -> t

  module Checked : sig
    val constant : t -> var

    val of_unsigned : magnitude_var -> var

    val if_ : Boolean.var -> then_:var -> else_:var -> (var, _) Checked.t

    val to_triples : var -> Boolean.var Triple.t list

    val add : var -> var -> (var, _) Checked.t

    val ( + ) : var -> var -> (var, _) Checked.t

    val to_field_var : var -> (Field.var, _) Checked.t

    val cswap :
         Boolean.var
      -> (magnitude_var, Sgn.t) t_ * (magnitude_var, Sgn.t) t_
      -> (var * var, _) Checked.t
  end
end

module Fee : sig
  include Basic

  include Arithmetic_intf with type t := t

  (* TODO: Get rid of signed fee, use signed amount *)
  module Signed :
    Signed_intf with type magnitude := t and type magnitude_var := var

  module Checked : sig
    include
      Checked_arithmetic_intf
      with type var := var
       and type signed_var := Signed.var
       and type t := t

    val add_signed : var -> Signed.var -> (var, _) Checked.t
  end
end

module Amount : sig
  include Basic

  include Arithmetic_intf with type t := t

  module Signed :
    Signed_intf with type magnitude := t and type magnitude_var := var

  (* TODO: Delete these functions *)

  val of_fee : Fee.t -> t

  val to_fee : t -> Fee.t

  val add_fee : t -> Fee.t -> t option

  module Checked : sig
    include
      Checked_arithmetic_intf
      with type var := var
       and type signed_var := Signed.var
       and type t := t

    val add_signed : var -> Signed.var -> (var, _) Checked.t

    val of_fee : Fee.var -> var

    val to_fee : var -> Fee.var

    val add_fee : var -> Fee.var -> (var, _) Checked.t
  end
end

module Balance : sig
  include Basic

  val to_amount : t -> Amount.t

  val add_amount : t -> Amount.t -> t option

  val sub_amount : t -> Amount.t -> t option

  val ( + ) : t -> Amount.t -> t option

  val ( - ) : t -> Amount.t -> t option

  module Checked : sig
    val add_signed_amount : var -> Amount.Signed.var -> (var, _) Checked.t

    val add_amount : var -> Amount.var -> (var, _) Checked.t

    val sub_amount : var -> Amount.var -> (var, _) Checked.t

    val ( + ) : var -> Amount.var -> (var, _) Checked.t

    val ( - ) : var -> Amount.var -> (var, _) Checked.t
  end
end
