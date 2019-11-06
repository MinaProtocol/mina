[%%import
"../../config.mlh"]

[%%if
curve_size = 298]

module Cycle = Snarky.Libsnark.Mnt298
module Snarkette_tick = Snarkette.Mnt6_80
module Snarkette_tock = Snarkette.Mnt4_80

[%%elif
curve_size = 753]

module Cycle = Snarky.Libsnark.Mnt753
module Snarkette_tick = Snarkette.Mnt6753
module Snarkette_tock = Snarkette.Mnt4753

[%%else]

[%%show
curve_size]

[%%error
"invalid value for \"curve_size\""]

[%%endif]

module Tick_full = Cycle.Mnt4
module Tock_full = Cycle.Mnt6

module Tock_backend = struct
  module Full = Tock_full
  include Full.Groth16
  module Inner_curve = Tick_full.G1
  module Inner_twisted_curve = Tick_full.G2
end

module Tock0 = Snarky.Snark.Make (Tock_backend)

module Tock_runner =
  Snarky.Snark.Run.Make
    (Tock_backend)
    (struct
      type t = unit
    end)
