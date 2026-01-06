(** Test to count the number of constraints in the transaction SNARK circuits.

    This test uses the constraint_counts function to get the number of rows
    (constraints) for each transaction SNARK circuit.

    The transaction SNARK has 5 rules:
    1. Base ("transaction") - Single non-zkApp transaction
    2. Merge ("merge") - Combines two proofs
    3. ZkApp Opt_signed_opt_signed - 2 optional signatures
    4. ZkApp Opt_signed - 1 optional signature
    5. ZkApp Proved - Side-loaded proof

    Note: Currently only Base and Merge constraint counts are exposed.
    ZkApp circuits would require additional interface changes to expose.

    This is useful for:
    - Tracking constraint count changes over time
    - Comparing with a Rust reimplementation
    - Performance analysis
*)

open Core_kernel

(** Count constraints in all transaction SNARK circuits *)
let count_transaction_snark_constraints () =
  let signature_kind = Mina_signature_kind.Testnet in
  let constraint_constants = Genesis_constants.Compiled.constraint_constants in
  let counts =
    Transaction_snark.constraint_counts ~signature_kind ~constraint_constants ()
  in
  Printf.printf "\n=== Transaction SNARK Constraint Summary ===\n%!" ;
  List.iter counts ~f:(fun (name, num_constraints) ->
      Printf.printf "%s constraints: %d\n%!" name num_constraints ;
      Alcotest.(check bool)
        (Printf.sprintf "%s has constraints" name)
        true (num_constraints > 0) ) ;
  Printf.printf "=============================================\n%!"

let () =
  let open Alcotest in
  run "Transaction Snark Constraint Count Tests"
    [ ( "Constraints"
      , [ test_case "Count" `Slow count_transaction_snark_constraints ] )
    ]
