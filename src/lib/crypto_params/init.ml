module Tick_curve = Snarky.Backends.Mnt4.GM
module Tock_curve = Snarky.Backends.Mnt6.GM
module Inner_curve = Snarky.Libsnark.Mnt6.Group
module Tick0 = Snarky.Snark.Make (Tick_curve)
