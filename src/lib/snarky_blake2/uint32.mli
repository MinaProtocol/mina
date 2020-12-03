module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  (** UInt32s are represented as a length 32, little-endian array of booleans *)
  type t = Boolean.var array

  module Unchecked = Unsigned.UInt32

  (** This is 32 *)
  val length_in_bits : int

  val constant : Unsigned.UInt32.t -> t

  val zero : t

  val xor : t -> t -> (t, _) Checked.t

  val sum : t list -> (t, _) Checked.t

  (** Rotate to the "right" (i.e., move higher bits down) *)
  val rotr : t -> int -> t

  val typ : (t, Unchecked.t) Typ.t
end

module Make (Impl : Snarky_backendless.Snark_intf.S) :
  S with module Impl := Impl
