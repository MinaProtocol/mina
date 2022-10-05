module Serializing = Graphql_lib.Serializing

module Insert =
[%graphql
{| mutation insert($fee_transfers: [fee_transfers_insert_input!]!) {
      insert_fee_transfers(objects: $fee_transfers,
      on_conflict: {constraint_: fee_transfers_hash_key, update_columns: [hash]}
      ) {
          returning {
              hash @ppxCustom(module: "Serializing.Transaction_hash")
              first_seen @ppxCustom(module: "Base_types.Optional_block_time")
            }
        }
    }
    |}]

module Query_first_seen =
[%graphql
{|
    query query_first_seen ($hashes: [String!]!) {
        fee_transfers(where: {hash: {_in: $hashes}} ) {
            hash @ppxCustom(module: "Serializing.Transaction_hash")
            first_seen @ppxCustom(module: "Base_types.Optional_block_time")
        }
    }
  |}]
