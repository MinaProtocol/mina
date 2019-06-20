include Non_zero_curve_point

include Codable.Make_of_string (struct
  type nonrec t = t

  let to_string t = Compressed.to_base58_check (compress t)

  let of_string string =
    Compressed.of_base58_check_exn string |> decompress_exn
end)

let of_private_key_exn p =
  of_inner_curve_exn Snark_params.Tick.Inner_curve.(scale_field one p)
