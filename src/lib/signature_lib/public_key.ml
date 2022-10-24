(* public_key.ml *)

include Non_zero_curve_point
module Inner_curve = Snark_params.Step.Inner_curve

let of_private_key_exn p = of_inner_curve_exn Inner_curve.(scale one p)
