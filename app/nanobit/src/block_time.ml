open Core_kernel
open Nanobit_base
open Snark_params

module Stable = struct
  module V1 = struct
    (* TODO: This should be stable. *)
    (* Milliseconds since epoch *)
    type t = Int64.t
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

include Bits.Snarkable.Int64(Tick)

module Span = struct
  module Stable = struct
    module V1 = struct
      type t = Int64.t [@@deriving bin_io, sexp]
    end
  end

  include Stable.V1

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
