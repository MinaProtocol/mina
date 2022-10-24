include Make_sponge.Make (Backend.Wrap.Field)

let params =
  (* HACK *)
  Sponge.Params.(
    let testbit n i = Bigint.(equal (shift_right n i land one) one) in
    map pasta_q_kimchi ~f:(fun s ->
        Backend.Wrap.Field.of_bits
          (List.init Backend.Wrap.Field.size_in_bits
             (testbit (Bigint.of_string s)) ) ))
