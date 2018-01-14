open Core_kernel

(* Milliseconds since epoch *)
type t = Int64.t
[@@deriving bin_io]

module Snarkable = Bits.Snarkable.Int64

module Span = struct
  module Snarkable = Bits.Snarkable.Int64
  type t = Int64.t [@@deriving bin_io]

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
