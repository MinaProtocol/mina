open Signature_lib
open Coda_base
open Core

let deserialize_optional_block_time =
  Option.map
    ~f:(Fn.compose Types.Block_time.deserialize Types.Bitstring.of_yojson)

module User_commands = struct
  module Get_existing =
  [%graphql
  {|
    query get_existing ($hashes: [String!]!) {
        user_commands(where: {hash: {_in: $hashes}} ) {
            id
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            first_seen @bsDecoder(fn: "deserialize_optional_block_time")
        }
    }
|}]

  let bitstring_block_time = Option.map ~f:Types.Bitstring.of_yojson

  open Types.User_command

  (* TODO: replace this with pagination *)
  module Query =
  [%graphql
  {|
    query query ($hash: String!) {
        user_commands(where: {hash: {_eq: $hash}} ) @bsRecord {
            fee @bsDecoder (fn: "Types.Bitstring.of_yojson")
            hash
            memo
            nonce @bsDecoder (fn: "Types.Bitstring.of_yojson")
            receiver
            sender
            typ @bsDecoder (fn: "Types.User_command_type.decode")
            amount @bsDecoder (fn: "Types.Bitstring.of_yojson")
            first_seen @bsDecoder(fn: "bitstring_block_time")
        }
    }
|}]

  module Update =
  [%graphql
  {|
    mutation get_existing ($current_id: Int!, $new_first_seen: bit!) {
        update_user_commands(where: {id: {_eq: $current_id}}, _set: {first_seen: $new_first_seen}) {
            affected_rows
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

module Public_keys = struct
  module Get_existing =
  [%graphql
  {|
    query get_existing ($public_keys: [String!]!) {
        public_keys(where: {value: {_in: $public_keys}} ) {
            id
            value @bsDecoder(fn: "Public_key.Compressed.of_base58_check_exn")
        }
    }
|}]

  module Insert =
  [%graphql
  {|
    mutation insert ($public_keys: [public_keys_insert_input!]!) {
        insert_public_keys(objects: $public_keys ) {
            returning {
                id
                value @bsDecoder(fn: "Public_key.Compressed.of_base58_check_exn")
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
