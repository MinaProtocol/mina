include Make_sponge.Make (Snarky_bn382_backend.Fq)

let params =
  (* HACK *)
  Sponge.Params.(
    let testbit n i = Bigint.(equal (shift_right n i land one) one) in
    map bn382_q ~f:(fun s ->
        Snarky_bn382_backend.Fq.of_bits
          (List.init Snarky_bn382_backend.Fq.size_in_bits
             (testbit (Bigint.of_string s))) ))
