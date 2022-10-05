(**  *)
module T
    (Impl : Snarky_backendless.Snark_intf.Run)
    (N : Pickles_types.Vector.Nat_intf) : sig
  type t = Impl.Field.t

  val length : int

  module Constant : module type of Constant.Make (N)

  val typ : (Impl.Field.t, Constant.t) Impl.Typ.t
end
