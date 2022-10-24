include Make_sponge.Make (Backend.Step.Field)

let params =
  (* HACK *)
  Sponge.Params.(
    let testbit n i = Bigint.(equal (shift_right n i land one) one) in
    map pasta_p_kimchi ~f:(fun s ->
        Backend.Step.Field.of_bits
          (List.init Backend.Step.Field.size_in_bits
             (testbit (Bigint.of_string s)) ) ))
