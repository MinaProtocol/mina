include Non_zero_curve_point

let of_private_key_exn p =
  of_inner_curve_exn Snark_params.Tick.Inner_curve.(scale_field one p)
