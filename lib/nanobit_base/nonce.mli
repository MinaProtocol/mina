open Core_kernel

type t = private Int64.t
[@@deriving sexp]

module Stable : sig
  module V1 : sig
    type nonrec t = t
    [@@deriving bin_io, sexp]
  end
end

val zero : t

val succ : t -> t

(* Someday: I think this only does ones greater than zero, but it doesn't really matter for
  selecting the nonce *)
val random : unit -> t

module Bits : Bits_intf.S with type t := t

include Snark_params.Tick.Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t
