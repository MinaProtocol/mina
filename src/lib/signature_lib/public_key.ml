(* public_key.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

include Non_zero_curve_point
module Inner_curve = Snark_params.Tick.Inner_curve

let of_private_key_exn p = of_inner_curve_exn Inner_curve.(scale one p)

[%%else]

include Non_zero_curve_point_nonconsensus.Non_zero_curve_point
module Inner_curve = Snark_params_nonconsensus.Inner_curve

let of_private_key_exn p = of_inner_curve_exn Inner_curve.(scale one p)

[%%endif]
