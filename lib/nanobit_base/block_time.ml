open Core_kernel
open Snark_params
open Tick
open Let_syntax
open Unsigned_extended
open Snark_bits

(* Milliseconds since epoch *)
module Stable = struct
  module V1 = struct
    type t = UInt64.t [@@deriving bin_io, sexp, compare, eq]
  end
end

include Stable.V1
module B = Bits

let bit_length = 64

module Bits = Bits.UInt64
include B.Snarkable.UInt64 (Tick)

module Span = struct
  module Stable = struct
    module V1 = struct
      type t = UInt64.t [@@deriving bin_io, sexp, compare]
    end
  end

  include Stable.V1
  module Bits = B.UInt64
  include B.Snarkable.UInt64 (Tick)

  let of_time_span s = UInt64.of_int64 (Int64.of_float (Time.Span.to_ms s))

  let to_ms = UInt64.to_int64

  let ( < ) = UInt64.( < )

  let ( > ) = UInt64.( > )

  let ( = ) = UInt64.( = )

  let ( <= ) = UInt64.( <= )

  let ( >= ) = UInt64.( >= )
end

let field_var_to_unpacked (x: Tick.Field.Checked.t) =
  Tick.Field.Checked.unpack ~length:64 x

let diff x y = UInt64.sub x y

let diff_checked x y =
  let pack = Tick.Field.Checked.project in
  Span.unpack_var Tick.Field.Checked.Infix.(pack x - pack y)

let unpacked_to_number var =
  let bits = Span.Unpacked.var_to_bits var in
  Number.of_bits bits

let of_time t =
  UInt64.of_int64
    (Int64.of_float (Time.Span.to_ms (Time.to_span_since_epoch t)))

let to_time t =
  Time.of_span_since_epoch
    (Time.Span.of_ms (Int64.to_float (UInt64.to_int64 t)))

let now () = of_time (Time.now ())
