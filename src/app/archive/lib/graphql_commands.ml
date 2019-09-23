open Signature_lib
open Coda_base
open Core

let graphql_uri port = Graphql_client_lib.make_local_uri port "v1/graphql"

let deserialize_block_time =
  Option.map
    ~f:(Fn.compose Types.Block_time.deserialize Types.Bitstring.of_yojson)

module User_commands = struct
  module Get_existing =
  [%graphql
  {|
    query get_existing ($hashes: [String!]!) @bsRecord {
        user_commands(where: {hash: {_in: $hashes}} ) {
            id
            hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
            first_seen @bsDecoder(fn: "deserialize_block_time")
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
mutation transaction_insert(
  $user_commands: [user_commands_insert_input!]!
) {
  insert_user_commands(objects: $user_commands,
  on_conflict: {constraint: user_commands_pkey, update_columns: first_seen}
  ) {
    returning {
      id
      hash @bsDecoder(fn: "Transaction_hash.of_base58_check_exn")
      first_seen @bsDecoder(fn: "deserialize_block_time")
    }
  }
}

|}]
end

module Public_keys = struct
  module Get_existing =
  [%graphql
  {|
    query get_existing ($public_keys: [String!]!) @bsRecord {
        public_keys(where: {hash: {_in: $public_keys}} ) {
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
