module type S = sig
  module Impl : Snarky.Snark_intf.S

  open Impl

  val block_size_in_bits : int
  (** Input will be padded to have length a multiple of
    this value, which is 512 *)

  val digest_length_in_bits : int
  (** The output will have length equal to this value
    which is 256 *)

  val blake2s :
       ?personalization:string
    -> Boolean.var array
    -> (Boolean.var array, _) Checked.t
  (** A checked version of the [blake2s] hash function. *)
end

module Make (Impl : Snarky.Snark_intf.S) : S with module Impl := Impl
