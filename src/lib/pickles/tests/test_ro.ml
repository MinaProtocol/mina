(* initially written to see the consistency between updates of digestif *)
let test_bits_random_oracle_consistency_check () =
  let s = "BitsRandomOracle" in
  let exp_output_str =
    "01000001101110001111111100011000011000100010100011010010110110010011101101101000001110001110100101010100001000001110101110111010"
  in
  let exp_output =
    List.map (fun i -> i = '1') (Core_kernel.String.to_list exp_output_str)
  in
  let output = Pickles.Ro.bits_random_oracle ~length:128 s in
  assert (List.for_all2 Bool.equal exp_output output)

let () =
  let open Alcotest in
  run "Pickles Random Oracle"
    [ ( "bits_random_oracle"
      , [ test_case "consistency_check" `Quick
            test_bits_random_oracle_consistency_check
        ] )
    ]
