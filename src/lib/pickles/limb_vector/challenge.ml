open Pickles_types

type 'f t = 'f Snarky_backendless.Cvar.t

module Constant = Constant.Make (Nat.N2)

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.Run

  open Impl

  type nonrec t = field t

  module Constant : sig
    type t = Constant.t [@@deriving sexp_of]

    val to_bits : t -> bool list

    val of_bits : bool list -> t

    val dummy : t
  end

  val typ : (t, Constant.t) Typ.t

  val length : int
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) :
  S with module Impl := Impl =
  Make.T (Impl) (Nat.N2)
