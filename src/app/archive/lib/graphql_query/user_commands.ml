module Serializing = Graphql_lib.Serializing

module Query_first_seen =
[%graphql
{|
    query query ($hashes: [String!]!) {
        user_commands(where: {hash: {_in: $hashes}} ) {
            hash @ppxCustom(module: "Serializing.Transaction_hash")
            first_seen @ppxCustom(module: "Base_types.Optional_block_time")
        }
    }
  |}]

module Query_participants =
[%graphql
{|
    query query ($hashes: [String!]!) {
        user_commands(where: {hash: {_in: $hashes}} ) {
          receiver {
            id
            value @ppxCustom(module: "Serializing.Public_key_s")
          }
          sender {
            id
            value @ppxCustom(module: "Serializing.Public_key_s")
          }
        }
    }
  |}]

(* TODO: replace this with pagination *)
module Query =
[%graphql
{|
    query query ($hash: String!) {
        user_commands(where: {hash: {_eq: $hash}} ) {
            fee @ppxCustom(module: "Base_types.Fee")
            hash @ppxCustom(module: "Serializing.Transaction_hash")
            memo @ppxCustom(module: "Serializing.Memo")
            nonce @ppxCustom(module: "Base_types.Nonce")
            sender {
                value @ppxCustom(module: "Serializing.Public_key_s")
            }
            receiver {
              value @ppxCustom(module: "Serializing.Public_key_s")
            }
            typ @ppxCustom(module: "Base_types.User_command_type")
            amount @ppxCustom(module: "Base_types.Amount")
            first_seen @ppxCustom(module: "Base_types.Optional_block_time")
        }
    }
  |}]

module Insert =
[%graphql
{|
    mutation insert ($user_commands: [user_commands_insert_input!]!) {
    insert_user_commands(objects: $user_commands,
    on_conflict: {constraint_: user_commands_hash_key, update_columns: [first_seen]}
    ) {
      returning {
        hash @ppxCustom(module: "Serializing.Transaction_hash")
        first_seen @ppxCustom(module: "Base_types.Optional_block_time")
      }
    }
  }
|}]
