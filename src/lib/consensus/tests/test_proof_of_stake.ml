(** Testing
    -------
    Component: Consensus.Proof_of_stake
    Subject: Testing the Proof of Stake module
    Invocation: dune exec \
      src/lib/consensus/tests/test_proof_of_stake.exe
*)

open Core
open Consensus

module Bootstrap_tests = struct
  let test_should_bootstrap_is_sane () =
    let module Context = struct
      let logger = Logger.create ()

      let constraint_constants =
        Genesis_constants.For_unit_tests.Constraint_constants.t

      let consensus_constants = Lazy.force Constants.for_unit_tests
    end in
    (* Even when consensus constants are of prod sizes, candidate should still
       trigger a bootstrap *)
    let result =
      Consensus.Proof_of_stake.Hooks.should_bootstrap_len
        ~context:(module Context)
        ~existing:Mina_numbers.Length.zero
        ~candidate:(Mina_numbers.Length.of_int 100_000_000)
    in
    Alcotest.(check bool) "should bootstrap with large candidate" true result
end

let () =
  let open Alcotest in
  run "Proof of Stake Tests"
    [ ( "Bootstrap"
      , [ test_case "should_bootstrap is sane" `Quick
            Bootstrap_tests.test_should_bootstrap_is_sane
        ] )
    ]
