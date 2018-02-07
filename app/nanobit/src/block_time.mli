open Core_kernel
open Nanobit_base
open Snark_params

type t [@@deriving sexp]

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.S
  with type Unpacked.value = t
   and type Packed.value = t

module Span : sig
  type t [@@deriving sexp]

  val of_time_span : Time.Span.t -> t

  include Tick.Snarkable.Bits.S
    with type Unpacked.value = t
    and type Packed.value = t

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving sexp, bin_io]
    end
  end
end

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp, bin_io]
  end
end

