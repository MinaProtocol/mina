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
