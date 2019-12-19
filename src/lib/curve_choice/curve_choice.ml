[%%import
"/src/config.mlh"]

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

include Functor.Make (Cycle)
