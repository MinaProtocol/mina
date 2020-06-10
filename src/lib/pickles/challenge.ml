open Pickles_types

type 'f t = 'f Snarky.Cvar.t Snarky.Boolean.t list

module Constant = Limb_vector.Constant.Make (Nat.N2)

module type S = sig
  module Impl : Snarky.Snark_intf.Run

  open Impl

  type nonrec t = field t

  module Constant : sig
    type t = Constant.t [@@deriving bin_io, sexp_of]

    val to_bits : t -> bool list

    val of_bits : bool list -> t

    val dummy : t
  end

  val typ : (t, Constant.t) Typ.t

  val packed_typ : (Field.t, Constant.t) Typ.t

  val to_bits : t -> Boolean.var list

  val length : int
end

module Make (Impl : Snarky.Snark_intf.Run) : S with module Impl := Impl =
  Limb_vector.Make (Impl) (Nat.N2)
