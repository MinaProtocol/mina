open Core_kernel
open Snark_params
open Snark_bits

type t [@@deriving sexp, eq]

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp, bin_io, compare, eq, hash]
  end
end

val bit_length : int

module Bits : Bits_intf.S with type t := t

include Tick.Snarkable.Bits.Faithful
        with type Unpacked.value = t
         and type Packed.value = t
         and type Packed.var = private Tick.Field.Checked.t

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

  val ( < ) : t -> t -> bool

  val ( > ) : t -> t -> bool

  val ( = ) : t -> t -> bool

  val ( <= ) : t -> t -> bool

  val ( >= ) : t -> t -> bool
end

module Timeout : sig
  type 'a t

  val create : Span.t -> (unit -> 'a) -> 'a t

  val to_deferred : 'a t -> 'a Async_kernel.Deferred.t

  val peek : 'a t -> 'a option

  val cancel : 'a t -> 'a -> unit
end

val field_var_to_unpacked :
  Tick.Field.Checked.t -> (Unpacked.var, _) Tick.Checked.t

val diff_checked :
  Unpacked.var -> Unpacked.var -> (Span.Unpacked.var, _) Tick.Checked.t

val unpacked_to_number : Span.Unpacked.var -> Tick.Number.t

val diff : t -> t -> Span.t

val modulus : t -> Span.t -> Span.t

val of_time : Time.t -> t

val to_time : t -> Time.t

val now : unit -> t
