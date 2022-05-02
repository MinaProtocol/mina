include Make_sponge.Make (Backend.Tick.Field)

let params =
  (* HACK *)
  Sponge.Params.(
    let testbit n i = Bigint.(equal (shift_right n i land one) one) in
    map pasta_p_kimchi ~f:(fun s ->
        Backend.Tick.Field.of_bits
          (List.init Backend.Tick.Field.size_in_bits
             (testbit (Bigint.of_string s)))))
