open Core_kernel
open Snark_params

(* Milliseconds since epoch *)
type t = Int64.t
[@@deriving bin_io, sexp]

include Bits.Snarkable.Int64(Tick)

module Span = struct
  type t = Int64.t [@@deriving bin_io]

  include Bits.Snarkable.Int64(Tick)

  let of_time_span s =
    Int64.of_float (Time.Span.to_ms s)
end

module Bits = Bits.Int64

let diff x y = Int64.(x - y)

let of_time t =
  Int64.of_float
    (Time.Span.to_ms
       (Time.to_span_since_epoch t))
;;

let to_time t =
  Time.of_span_since_epoch
    (Time.Span.of_ms (Int64.to_float t))
;;
