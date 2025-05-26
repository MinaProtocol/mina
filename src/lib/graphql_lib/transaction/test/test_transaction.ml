(* Testing
   -------

   Component: Transaction / GraphQL
   Subject: Test GraphQL scalars
   Invocation: dune exec src/lib/graphql_lib/transaction/test/test_transaction.exe
*)

include Mina_graphql_transaction.Make (Graphql_basic_scalars.Testing.Test_schema)
module Make_test = Graphql_basic_scalars.Testing.Produce_test

module TransactionHash_gen = struct
  include Mina_transaction.Transaction_hash
  open Core_kernel

  let gen =
    Mina_base.Coinbase.Gen.gen
      ~constraint_constants:
        Genesis_constants.For_unit_tests.Constraint_constants.t
    |> Quickcheck.Generator.map ~f:(fun (coinbase, _) ->
           hash_coinbase coinbase )
end

module TransactionId_gen = struct
  include Mina_base.User_command.Stable.Latest

  let gen = Mina_base.User_command.gen
end

module TransactionHash_test = Make_test (TransactionHash) (TransactionHash_gen)
module TransactionId_test = Make_test (TransactionId) (TransactionId_gen)

let test_transaction_hash () = TransactionHash_test.run_test_alcotest ()

let test_transaction_id () = TransactionId_test.run_test_alcotest ()

let () =
  let open Alcotest in
  run "Transaction GraphQL"
    [ ( "GraphQL scalars"
      , [ test_case "transaction hash query" `Quick test_transaction_hash
        ; test_case "transaction id query" `Quick test_transaction_id
        ] )
    ]
