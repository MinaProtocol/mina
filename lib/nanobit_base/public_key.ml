open Snark_params

(* Should this be functorized over the field? *)
type t0 = Tick.Field.t * Tick.Field.t [@@deriving bin_io]
type t = t0 [@@deriving bin_io]
module Compressed = struct
  type t = t0 [@@deriving bin_io]
end

let compress (t : t) : Compressed.t = t
let decompress (t : t) : Compressed.t = t

