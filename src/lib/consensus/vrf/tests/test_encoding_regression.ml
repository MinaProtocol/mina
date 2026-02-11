(** Testing
    -------
    Component:  Consensus_vrf
    Invocation: dune exec \
                  src/lib/consensus/vrf/tests/test_encoding_regression.exe
    Subject:    Regression tests for base58 encoding of VRF types.
 *)

(* Consensus_vrf.Output.Truncated.dummy = all-zero bytes *)
let test_vrf_truncated_output_dummy_encoding () =
  let expected = "48FSq2zFhVrXiBXjBbqchBFR1RsQWbEESTY1CM4zzroAKk7KKErp" in
  let got =
    Consensus_vrf.Output.Truncated.to_base58_check
      Consensus_vrf.Output.Truncated.dummy
  in
  Alcotest.(check string)
    "Consensus_vrf.Output.Truncated.dummy encoding is stable" expected got

let () =
  let open Alcotest in
  run "Base58 encoding regression"
    [ ( "base58 encoding regression"
      , [ test_case "VRF truncated output dummy encoding" `Quick
            test_vrf_truncated_output_dummy_encoding
        ] )
    ]
