include Make_sponge.Make (Backend.Tock.Field)

let params =
  (* HACK *)
  Sponge.Params.(
    let testbit n i = Bigint.(equal (shift_right n i land one) one) in
    map tweedle_p ~f:(fun s ->
        Backend.Tock.Field.of_bits
          (List.init Backend.Tock.Field.size_in_bits
             (testbit (Bigint.of_string s))) ))
