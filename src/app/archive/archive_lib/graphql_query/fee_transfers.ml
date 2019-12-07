open Coda_base

module Insert =
[%graphql
{| mutation insert($fee_transfers: [fee_transfers_insert_input!]!) {
      insert_fee_transfers(objects: $fee_transfers, on_conflict: {constraint: fee_transfers_hash_key, update_columns: hash}
      ) {
          returning {
              hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
              first_seen @bsDecoder(fn: "Base_types.deserialize_optional_block_time")
            }
        }
    }
    |}]

module Query_first_seen =
[%graphql
{|
    query query_first_seen ($hashes: [String!]!) {
        fee_transfers(where: {hash: {_in: $hashes}} ) {
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            first_seen @bsDecoder(fn: "Base_types.deserialize_optional_block_time")
        }
    }
  |}]
