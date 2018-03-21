open Core_kernel
open Snark_params
open Tick
open Let_syntax

(* Milliseconds since epoch *)
module Stable = struct
  module V1 = struct
    type t = Int64.t
    [@@deriving bin_io, sexp, compare]
  end
end

include Stable.V1

module B = Bits

module Bits = Bits.Int64
include B.Snarkable.Int64(Tick)

module Span = struct
  module Stable = struct
    module V1 = struct
      type t = Int64.t [@@deriving bin_io, sexp, compare]
    end
  end

  include Stable.V1

  module Bits = B.Int64
  include B.Snarkable.Int64(Tick)

  let of_time_span s =
    Int64.of_float (Time.Span.to_ms s)

  let to_ms t = t
end

let field_var_to_unpacked (x : Tick.Cvar.t) = Tick.Checked.unpack ~length:64 x

let diff x y = Int64.(x - y)

let diff_checked x y =
  let pack = Tick.Checked.project in
  Span.unpack_var Tick.Cvar.Infix.(pack x - pack y)
;;

let unpacked_to_number var =
  let bits = Span.Unpacked.var_to_bits var in
  Number.of_bits bits
;;

let of_time t =
  Int64.of_float
    (Time.Span.to_ms
       (Time.to_span_since_epoch t))
;;

let to_time t =
  Time.of_span_since_epoch
    (Time.Span.of_ms (Int64.to_float t))
;;
