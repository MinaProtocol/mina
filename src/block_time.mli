open Core_kernel

type t [@@deriving bin_io]

module Snarkable : functor (Impl : Snark_intf.S) ->
  Impl.Snarkable.Bits.S
  with type Unpacked.value = t
   and type Unpacked.Padded.value = t
   and type Packed.value = t

module Span : sig
  type t [@@deriving bin_io]

  module Snarkable : functor (Impl : Snark_intf.S) ->
    Impl.Snarkable.Bits.S
    with type Unpacked.value = t
    and type Unpacked.Padded.value = t
    and type Packed.value = t

  val of_time_span : Time.Span.t -> t
end

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t
