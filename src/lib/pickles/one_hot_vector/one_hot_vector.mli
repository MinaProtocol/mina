(** From Wikipedia (https://en.wikipedia.org/wiki/One-hot):
    "In digital circuits and machine learning, a one-hot is a group of bits
    among which the legal combinations of values are only those with a 
    single high (1) bit and all the others low (0)".
  *)

open Pickles_types

module Constant : sig
  type t = int
end

(** Represents a vector of ['n] circuit booleans. *)
type ('f, 'n) t =
  private
  ('f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t, 'n) Vector.t

(** A functor to create our type [t] from a snarky interface. *)
module T (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type nonrec 'n t = (Impl.field, 'n) t
end

(** A functor to create our type [t], as well as a number of useful methods, 
  from a snarky interface.
   *)
module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  open Impl
  module Constant = Constant

  (** A one-hot vector. A vector containing ['n] booleans, 
      of which only one is set to [true]. 
      *)
  type 'n t = 'n T(Impl).t

  (** `of_index i ~length` Creates a one-hot vector where only
      the i-th element is set to true.
      *)
  val of_index : Field.t -> length:'n Nat.t -> 'n t

  (** Converts a [Vector.t] directly into a [t]. *)
  val of_vector_unsafe : (Impl.Boolean.var, 'n) Vector.t -> 'n t

  (** Converts a [Nat.t] into a [Typ.t] representing the type
      of [t] in a circuit. 
  *)
  val typ : 'n Nat.t -> ('n t, Constant.t) Typ.t
end
