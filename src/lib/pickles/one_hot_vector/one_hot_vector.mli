open Pickles_types

module Constant : sig
  type t = int
end

module T (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type 'n t = private (Impl.Boolean.var, 'n) Vector.t
end

module Make
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit) : sig
  open Impl
  module Constant = Constant

  type 'n t = 'n T(Impl).t

  val of_index : Field.t -> length:'n Nat.t -> 'n t

  val typ : 'n Nat.t -> ('n t, Constant.t) Typ.t
end
