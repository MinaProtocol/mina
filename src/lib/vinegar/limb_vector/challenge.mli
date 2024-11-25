type 'f t = 'f Snarky_backendless.Cvar.t

module Constant : module type of Constant.Make (Pickles_types.Nat.N2)

module type S = sig
  module Impl : Snarky_backendless.Snark_intf.Run

  type nonrec t = Impl.field t

  module Constant : sig
    type t = Constant.t [@@deriving sexp_of]

    val to_bits : t -> bool list

    val of_bits : bool list -> t

    val dummy : t
  end

  val typ : (t, Constant.t) Impl.Typ.t

  val length : int
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) :
  S with module Impl := Impl
