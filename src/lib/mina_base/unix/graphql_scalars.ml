open Graphql_basic_scalars

module TokenId =
  Make_scalar_using_to_string
    (Mina_base.Token_id)
    (struct
      let name = "TokenId"

      let doc = "String representation of a token's UInt64 identifier"
    end)

module StateHash =
  Make_scalar_using_base58_check
    (Mina_base.State_hash)
    (struct
      let name = "StateHash"

      let doc = "Base58Check-encoded state hash"
    end)

module ChainHash =
  Make_scalar_using_base58_check
    (Mina_base.Receipt.Chain_hash)
    (struct
      let name = "ChainHash"

      let doc = "Base58Check-encoded chain hash"
    end)

module EpochSeed =
  Make_scalar_using_base58_check
    (Mina_base.Epoch_seed)
    (struct
      let name = "EpochSeed"

      let doc = "Base58Check-encoded epoch seed"
    end)

module LedgerHash =
  Make_scalar_using_base58_check
    (Mina_base.Ledger_hash)
    (struct
      let name = "LedgerHash"

      let doc = "Base58Check-encoded ledger hash"
    end)

module StagedLedgerAuxHash =
  Make_scalar_using_base58_check
    (Mina_base.Staged_ledger_hash.Aux_hash)
    (struct
      let name = "StagedLedgerAuxHash"

      let doc = "Base58Check-encoded hash of the staged ledger hash's aux_hash"
    end)

module PendingCoinbaseHash =
  Make_scalar_using_base58_check
    (Mina_base.Pending_coinbase.Hash)
    (struct
      let name = "PendingCoinbaseHash"

      let doc = "Base58Check-encoded hash of a pending coinbase hash"
    end)

module PendingCoinbaseAuxHash =
  Make_scalar_using_base58_check
    (Mina_base.Staged_ledger_hash.Pending_coinbase_aux)
    (struct
      let name = "PendingCoinbaseAuxHash"

      let doc = "Base58Check-encoded hash of a pending coinbase auxiliary hash"
    end)

module FieldElem =
  Make_scalar_using_to_string
    (Mina_base.Zkapp_basic.F)
    (struct
      let name = "FieldElem"

      let doc = "field element"
    end)

module TransactionStatusFailure :
  Json_intf with type t = Mina_base.Transaction_status.Failure.t = struct
  open Mina_base.Transaction_status.Failure

  type nonrec t = t

  let parse json =
    json |> Yojson.Basic.Util.to_string |> of_string
    |> Base.Result.ok_or_failwith

  let serialize x = `String (to_string x)

  let typ () =
    Graphql_async.Schema.scalar "TransactionStatusFailure"
      ~doc:"transaction status failure" ~coerce:serialize
end

(* TESTS *)

module FieldElem_gen = struct
  include Mina_base.Zkapp_basic.F

  let gen =
    Core_kernel.Int.quickcheck_generator
    |> Core_kernel.Quickcheck.Generator.map ~f:Pasta_bindings.Fp.of_int
end

module StagedledgerAuxHash_gen = struct
  include Mina_base.Staged_ledger_hash.Aux_hash
end

let%test_module "TokenId" = (module Make_test (TokenId) (Mina_base.Token_id))

let%test_module "StateHash" =
  (module Make_test (StateHash) (Mina_base.State_hash))

let%test_module "ChainHash" =
  (module Make_test (ChainHash) (Mina_base.Receipt.Chain_hash))

let%test_module "EpochSeed" =
  (module Make_test (EpochSeed) (Mina_base.Epoch_seed))

let%test_module "LedgerHash" =
  (module Make_test (LedgerHash) (Mina_base.Ledger_hash))

let%test_module "TransactionStatusFailure" =
  ( module Make_test
             (TransactionStatusFailure)
             (Mina_base.Transaction_status.Failure) )

let%test_module "FieldElem" = (module Make_test (FieldElem) (FieldElem_gen))

let%test_module "PendingCoinbaseHash" =
  (module Make_test (PendingCoinbaseHash) (Mina_base.Pending_coinbase.Hash))

let%test_module "StagedLedgerAuxHash" =
  (module Make_test (StagedLedgerAuxHash) (StagedledgerAuxHash_gen))
