open Graphql_basic_scalars

module TransactionHash =
  Make_scalar_using_base58_check
    (Mina_transaction.Transaction_hash)
    (struct
      let name = "TransactionHash"

      let doc = "Base58Check-encoded transaction hash"
    end)

module TransactionId =
  Make_scalar_using_base64
    (Mina_transaction.Transaction_id)
    (struct
      let name = "TransactionId"

      let doc = "Base64-encoded transaction"
    end)

(* TESTS *)

let%test_module "TransactionHash" =
  ( module struct
    module TransactionHash_gen = struct
      include Mina_transaction.Transaction_hash
      open Core_kernel

      let gen =
        Mina_base.Coinbase.Gen.gen
          ~constraint_constants:
            Genesis_constants.Constraint_constants.for_unit_tests
        |> Quickcheck.Generator.map ~f:(fun (coinbase, _) ->
               hash_coinbase coinbase )
    end

    include Make_test (TransactionHash) (TransactionHash_gen)
  end )

let%test_module "TransactionId" =
  ( module struct
    module TransactionId_gen = struct
      include Mina_transaction.Transaction_id.User_command
    end

    include Make_test (TransactionId) (TransactionId_gen)
  end )
