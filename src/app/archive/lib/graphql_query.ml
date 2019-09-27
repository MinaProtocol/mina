open Signature_lib
open Coda_base
open Core

let deserialize_optional_block_time =
  Option.map
    ~f:(Fn.compose Types.Block_time.deserialize Types.Bitstring.of_yojson)

module User_commands = struct
  let bitstring_block_time = Option.map ~f:Types.Bitstring.of_yojson

  (* TODO: replace this with pagination *)
  module Query =
  [%graphql
  {|
    query query ($hash: String!) {
        user_commands(where: {hash: {_eq: $hash}} ) {
            fee @bsDecoder (fn: "Types.Bitstring.of_yojson")
            hash
            memo
            nonce @bsDecoder (fn: "Types.Bitstring.of_yojson")
            public_key {
                value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
            }
            publicKeyByReceiver {
              value @bsDecoder (fn: "Public_key.Compressed.of_base58_check_exn")
            } 
            typ @bsDecoder (fn: "Types.User_command_type.decode")
            amount @bsDecoder (fn: "Types.Bitstring.of_yojson")
            first_seen @bsDecoder(fn: "bitstring_block_time")
        }
    }
|}]

  module Insert =
  [%graphql
  {|
    mutation transaction_insert($user_commands: [user_commands_insert_input!]!) {
    insert_user_commands(objects: $user_commands,
    on_conflict: {constraint: user_commands_pkey, update_columns: first_seen}
    ) {
      returning {
        id
        hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
        first_seen @bsDecoder(fn: "deserialize_optional_block_time")
      }
    }
  }
|}]
end

module Clear_data =
[%graphql
{|
  mutation clear  {
    delete_user_commands(where: {}) {
      affected_rows
    }
      
    delete_public_keys(where: {}) {
      affected_rows
    }

  }
|}]
