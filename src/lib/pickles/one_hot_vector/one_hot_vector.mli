open Pickles_types

module Constant : sig
  type t = int
end

type ('f, 'n) t =
  private
  ('f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t, 'n) Vector.t

module T (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type nonrec 'n t = (Impl.field, 'n) t
end

module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  open Impl
  module Constant = Constant

  type 'n t = 'n T(Impl).t

  val of_index : Field.t -> length:'n Nat.t -> 'n t

  val of_vector_unsafe : (Impl.Boolean.var, 'n) Vector.t -> 'n t

  val typ : 'n Nat.t -> ('n t, Constant.t) Typ.t
end
