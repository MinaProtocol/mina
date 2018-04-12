open Core_kernel
open Snark_params

type t [@@deriving sexp, bin_io]

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp, bin_io, compare]
  end
end

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.Faithful
  with type Unpacked.value = t
   and type Packed.value = t
   and type Packed.var = private Tick.Cvar.t

module Span : sig
  type t [@@deriving sexp]

  module Stable : sig
    module V1 : sig
      type nonrec t = t [@@deriving bin_io, sexp, compare]
    end
  end

  val of_time_span : Time.Span.t -> t

  include Tick.Snarkable.Bits.Faithful
    with type Unpacked.value = t
    and type Packed.value = t

  val to_ms : t -> Int64.t
end

val field_var_to_unpacked : Tick.Cvar.t -> (Unpacked.var, _) Tick.Checked.t

val diff_checked
  : Unpacked.var -> Unpacked.var -> (Span.Unpacked.var, _) Tick.Checked.t

val unpacked_to_number 
  : Span.Unpacked.var -> Tick.Number.t

val diff : t -> t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t

val now : unit -> t
