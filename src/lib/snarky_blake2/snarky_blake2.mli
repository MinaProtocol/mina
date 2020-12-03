module type S = sig
  module Impl : Snarky_backendless.Snark_intf.S

  open Impl

  (** Input will be padded to have length a multiple of
    this value, which is 512 *)
  val block_size_in_bits : int

  (** The output will have length equal to this value
    which is 256 *)
  val digest_length_in_bits : int

  (** A checked version of the [blake2s] hash function. *)
  val blake2s :
       ?personalization:string
    -> Boolean.var array
    -> (Boolean.var array, _) Checked.t
end

module Make (Impl : Snarky_backendless.Snark_intf.S) :
  S with module Impl := Impl
