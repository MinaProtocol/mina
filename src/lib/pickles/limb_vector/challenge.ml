open Pickles_types

type 'f t = 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t list

module Constant = Constant.Make (Nat.N2)

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.Run

  open Impl

  type nonrec t = field t

  module Constant : sig
    type t = Constant.t [@@deriving bin_io, sexp_of]

    val to_bits : t -> bool list

    val of_bits : bool list -> t

    val dummy : t
  end

  val typ' : [`Constrained | `Unconstrained] -> (t, Constant.t) Typ.t

  val typ_unchecked : (t, Constant.t) Typ.t

  val packed_typ : (Field.t, Constant.t) Typ.t

  val to_bits : t -> Boolean.var list

  val length : int
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) :
  S with module Impl := Impl =
  Make.T (Impl) (Nat.N2)
