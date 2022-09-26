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

module ZkappCommandBase58 =
  Make_scalar_using_base58_check
    (Mina_base.Zkapp_command)
    (struct
      let name = "ZkappCommandBase58"

      let doc = "A Base58Check string representing the command"
    end)
