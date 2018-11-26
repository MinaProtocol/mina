include Non_zero_curve_point

include Codable.Make_of_string (struct
  type nonrec t = t

  let to_string t = Compressed.to_base64 (compress t)

  let of_string string = decompress_exn (Compressed.of_base64_exn string)
end)

let of_private_key_exn p =
  of_inner_curve_exn Snark_params.Tick.Inner_curve.(scale_field one p)
