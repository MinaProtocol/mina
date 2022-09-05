open Graphql_basic_scalars

module TransactionHash =
  Make_scalar_using_base58_check
    (Mina_transaction.Transaction_hash)
    (struct
      let name = "TransactionHash"

      let doc = "Base58Check-encoded transaction hash"
    end)


(* TESTS *)
module TransactionHash_gen = struct
  include Mina_transaction.Transaction_hash
  open Core_kernel
  let gen =
    Mina_base.Coinbase.Gen.gen
      ~constraint_constants:
        Genesis_constants.Constraint_constants.for_unit_tests
    |> Quickcheck.Generator.map ~f:(fun (coinbase, _) -> hash_coinbase coinbase)
end

let%test_module "TransactionHash" =
  (module Make_test (TransactionHash) (TransactionHash_gen))
