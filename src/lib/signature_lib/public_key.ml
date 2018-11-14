include Non_zero_curve_point

let to_yojson (x, y) =
  let s = Snark_params.Tick.Field.to_string in
  `List [`String (s x); `String (s y)]

let of_private_key_exn p =
  of_inner_curve_exn Snark_params.Tick.Inner_curve.(scale_field one p)
