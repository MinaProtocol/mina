(** Testing
    -------
    Component: Consensus_vrf
    Subject: Testing the Proof of Stake VRF module
    Invocation: dune exec \
      src/lib/consensus/vrf/tests/test_consensus_vrf.exe
*)

open Core_kernel

let test_hash_checked_and_unchecked () =
  let open Quickcheck.Generator.Let_syntax in
  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t
  in
  let gen_inner_curve_point =
    let%map compressed = Non_zero_curve_point.gen in
    Non_zero_curve_point.to_inner_curve compressed
  in
  let gen_message_and_curve_point =
    let%map msg = Consensus_vrf.Message.gen ~constraint_constants
    and g = gen_inner_curve_point in
    (msg, g)
  in
  Quickcheck.test ~trials:10 gen_message_and_curve_point
    ~f:
      (Test_util.test_equal ~equal:Snark_params.Tick.Field.equal
         Snark_params.Tick.Typ.(
           Consensus_vrf.Message.typ ~constraint_constants
           * Snark_params.Tick.Inner_curve.typ)
         Consensus_vrf.Output.typ
         (fun (msg, g) -> Consensus_vrf.Output.Checked.hash msg g)
         (fun (msg, g) -> Consensus_vrf.Output.hash ~constraint_constants msg g) )

let standalone_and_integrates_vrf_are_consistent () =
  let open Quickcheck.Generator.Let_syntax in
  let constraint_constants =
    Genesis_constants.For_unit_tests.Constraint_constants.t
  in
  let module Standalone = Consensus_vrf.Standalone (struct
    let constraint_constants = constraint_constants
  end) in
  let inputs =
    let%bind private_key = Signature_lib.Private_key.gen in
    let%map message = Consensus_vrf.Message.gen ~constraint_constants in
    (private_key, message)
  in
  Quickcheck.test ~seed:(`Deterministic "") inputs
    ~f:(fun (private_key, message) ->
      let integrated_vrf =
        Consensus_vrf.Integrated.eval ~constraint_constants ~private_key message
      in
      let standalone_eval = Standalone.Evaluation.create private_key message in
      let context : Standalone.Context.t =
        { message
        ; public_key =
            Signature_lib.Public_key.of_private_key_exn private_key
            |> Consensus_vrf.Group.of_affine
        }
      in
      let standalone_vrf =
        Standalone.Evaluation.verified_output standalone_eval context
      in
      assert (
        match standalone_vrf with
        | None ->
            Alcotest.fail "Standalone VRF evaluation failed"
        | Some standalone_vrf ->
            (* Check that the standalone VRF output matches the integrated VRF output *)
            if Snark_params.Tick.Field.equal standalone_vrf integrated_vrf then
              true
            else
              let str_standalone_vrf =
                Snark_params.Tick.Field.to_string standalone_vrf
              in
              let str_integrated_vrf =
                Snark_params.Tick.Field.to_string integrated_vrf
              in
              Alcotest.failf
                "Standalone VRF output %s does not match integrated VRF output \
                 %s"
                str_standalone_vrf str_integrated_vrf ) )

let () =
  let open Alcotest in
  run "VRF Tests"
    [ ( "standalone_and_integrates_vrf_are_consistent"
      , [ test_case "Check consistency" `Quick
            standalone_and_integrates_vrf_are_consistent
        ] )
    ; ( "Hash checked and unchecked"
      , [ test_case "Check hash consistency" `Quick
            test_hash_checked_and_unchecked
        ] )
    ]
