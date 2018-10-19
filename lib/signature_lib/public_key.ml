open Core_kernel

module Private_key = Private_key

include Non_zero_curve_point

let to_curve_pair = Fn.id

let of_private_key_exn p =
  let open Snark_params.Tick.Inner_curve in
  of_inner_curve_exn (scale_field one (Private_key.to_curve_scalar p))
