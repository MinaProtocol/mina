(* Points on elliptic curves over finite fields by M. SKALBA
 * found at eg https://www.impan.pl/pl/wydawnictwa/czasopisma-i-serie-wydawnicze/acta-arithmetica/all/117/3/82159/points-on-elliptic-curves-over-finite-fields
 *)
open Core

module type Field_intf = sig
  type t

  val ( + ) : t -> t -> t

  val ( * ) : t -> t -> t

  val ( / ) : t -> t -> t

  val t_of_sexp : Sexp.t -> t

  val of_int : int -> t

  val one : t

  val zero : t

  val negate : t -> t
end

module type Unchecked_field_intf = sig
  include Field_intf

  val sqrt : t -> t

  val equal : t -> t -> bool

  val is_square : t -> bool

  val sexp_of_t : t -> Sexp.t
end

module Intf (F : sig
  type t
end) : sig
  module type S = sig
    val to_group : F.t -> F.t * F.t
  end
end

module Make_group_map
    (F : Field_intf) (Params : sig
        val a : F.t

        val b : F.t
    end) : sig
  val make_x1 : F.t -> F.t

  val make_x2 : F.t -> F.t

  val make_x3 : F.t -> F.t
end

module Make_unchecked
    (F : Unchecked_field_intf) (Params : sig
        val a : F.t

        val b : F.t
    end) : sig
  val to_group : F.t -> F.t * F.t
end
