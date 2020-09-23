open Coda_base
open Signature_lib

module Query_first_seen =
[%graphql
{|
    query query ($hashes: [String!]!) {
        user_commands(where: {hash: {_in: $hashes}} ) {
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            first_seen @bsDecoder(fn: "Base_types.deserialize_optional_block_time")
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
            value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
          }
          sender {
            id
            value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
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
            fee @bsDecoder (fn: "Base_types.Fee.deserialize")
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            memo @bsDecoder(fn: "Signed_command_memo.of_string")
            nonce @bsDecoder (fn: "Base_types.Nonce.deserialize")
            sender {
                value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
            }
            receiver {
              value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
            } 
            typ @bsDecoder (fn: "Base_types.User_command_type.decode")
            amount @bsDecoder (fn: "Base_types.Amount.deserialize")
            first_seen @bsDecoder(fn: "Base_types.deserialize_optional_block_time")
        }
    }
  |}]

module Insert =
[%graphql
{|
    mutation insert ($user_commands: [user_commands_insert_input!]!) {
    insert_user_commands(objects: $user_commands,
    on_conflict: {constraint: user_commands_hash_key, update_columns: first_seen}
    ) {
      returning {
        hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
        first_seen @bsDecoder(fn: "Base_types.deserialize_optional_block_time")
      }
    }
  }
|}]
