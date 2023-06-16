(** Type representation of a vector of [N.t] limbs *)
module T (Impl : Snarky_backendless.Snark_intf.Run) (N : Pickles_types.Nat.Intf) : sig
  type t = Impl.Field.t

  (** Returns the length of the vector as a runtime integer *)
  val length : int

  module Constant : module type of Constant.Make (N)

  val typ : (Impl.Field.t, Constant.t) Impl.Typ.t
end
