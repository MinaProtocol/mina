open Core_kernel

type t [@@deriving sexp, bin_io]

module Bits : Bits_intf.S with type t := t

include Snark_params.Main.Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t

module Span : sig
  type t [@@deriving bin_io]

  val of_time_span : Time.Span.t -> t

  include Snark_params.Main.Snarkable.Bits.S
    with type Unpacked.value = t
    and type Packed.value = t
end

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t
