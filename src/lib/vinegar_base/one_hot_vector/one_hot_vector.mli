(** Represents a typed size one-hot vector, which is list of bits where exactly
    one of the bit is one. As usual in Pickles, we encode the length at the type
    level and a type parameter is used to represent the finite field the vector bits
    are encoded in. Booleans are used to represent [0] and [1].

    More information can be found on the {{
    https://en.wikipedia.org/wiki/One-hot } wikipedia article }.
*)

open Pickles_types

module Constant : sig
  type t = int
end

(** Represents a one-hot vector of length ['n]. The type parameter ['f] is used
    to encod the field the vector lives in. For instance, if we want to
    represent the one-hot vector [0; 0; 1; 0; 0] in the finite field [F13], we
    would use the type [(F13.t, Nat.N5) t]. To activate the third bit, we would
    use the function [of_index] provided below.
*)
type ('f, 'n) t =
  private
  ('f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t, 'n) Vector.t

(** Concrete instance of a one-hot vector using an implementation Impl
    TODO: why don't we merge this functor with {!Make}? *)
module T (Impl : Snarky_backendless.Snark_intf.Run) : sig
  type nonrec 'n t = (Impl.field, 'n) t
end

(** Concrete instance of a one-hot vector with some helpers *)
module Make (Impl : Snarky_backendless.Snark_intf.Run) : sig
  module Constant = Constant

  type 'n t = 'n T(Impl).t

  (** [of_index f_idx t_n] creates a one hot vector of size [t_n] which only the
      index [f_idx] is set to [true].
      For instance, if we suppose [F13] is the finite field of order [13], the
      one-hot vector [0; 0; 1; 0; 0] in [F13] can be created
      using [of_index (F13.of_int 2) Nat.N5] *)
  val of_index : Impl.Field.t -> length:'n Nat.t -> 'n t

  (** [of_vector_unsafe v] creates a one-hot vector from a [n] long vector.
      However, the function does not check if strictly one bit is set to [1].
      Use {!of_index} for the safe version *)
  val of_vector_unsafe : (Impl.Boolean.var, 'n) Vector.t -> 'n t

  val typ : 'n Nat.t -> ('n t, Constant.t) Impl.Typ.t
end
