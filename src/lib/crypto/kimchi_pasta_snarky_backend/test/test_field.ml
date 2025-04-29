open Core_kernel

module Make (Field : Kimchi_pasta_snarky_backend.Field.S_with_version) = struct
  let test_field_sexp_round_trip () =
    let t = Field.random () in
    Alcotest.(check bool)
      "Sexp round trip" true
      (Field.equal t (Field.t_of_sexp (Field.sexp_of_t t)))

  let test_field_bin_io_round_trip () =
    let t = Field.random () in
    Alcotest.(check bool)
      "Bin_io round trip" true
      (Field.equal t
         (Binable.of_string
            (module Field.Stable.Latest)
            (Binable.to_string (module Field.Stable.Latest) t) ) )

  let test_field_of_bits_to_bits () =
    let x = Field.random () in
    Alcotest.(check bool)
      "of_bits to_bits round trip" true
      (Field.equal x (Field.of_bits (Field.to_bits x)))

  let test_field_to_bits_of_bits () =
    (* Generate random bits with one less than size_in_bits *)
    let bs = List.init (Field.size_in_bits - 1) ~f:(fun _ -> Random.bool ()) in
    (* Append false as the last bit *)
    let expected_bits = bs @ [ false ] in
    let result_bits = Field.to_bits (Field.of_bits bs) in
    Alcotest.(check (list bool))
      "to_bits of_bits equivalence" expected_bits result_bits
end

module Pallas = Make (Kimchi_pasta_snarky_backend.Pallas_based_plonk.Field)
module Vesta = Make (Kimchi_pasta_snarky_backend.Vesta_based_plonk.Field)

let () =
  let open Alcotest in
  run "Field Tests"
    [ ( "Pallas"
      , [ test_case "sexp round trip" `Quick Pallas.test_field_sexp_round_trip
        ; test_case "bin_io round trip" `Quick
            Pallas.test_field_bin_io_round_trip
        ; test_case "of_bits to_bits" `Quick Pallas.test_field_of_bits_to_bits
        ; test_case "to_bits of_bits" `Quick Pallas.test_field_to_bits_of_bits
        ] )
    ; ( "Vesta"
      , [ test_case "sexp round trip" `Quick Vesta.test_field_sexp_round_trip
        ; test_case "bin_io round trip" `Quick
            Vesta.test_field_bin_io_round_trip
        ; test_case "of_bits to_bits" `Quick Vesta.test_field_of_bits_to_bits
        ; test_case "to_bits of_bits" `Quick Vesta.test_field_to_bits_of_bits
        ] )
    ]
