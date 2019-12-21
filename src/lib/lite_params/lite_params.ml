module Tock = Lite_curve_choice.Tock

let pedersen_params = Pedersen_params.pedersen_params

module Pedersen = Pedersen_lib.Pedersen.Make (Tock.Fq) (Tock.G1)
