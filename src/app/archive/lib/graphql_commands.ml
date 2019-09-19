let graphql_uri port = Graphql_client_lib.make_local_uri port "v1/graphql"

module Transaction_pool_get_existing =
[%graphql
{|
    query get_existing ($hashes: [String!]!) {
        user_commands(where: {hash: {_in: $hashes}} ) {
            hash,
            first_seen
        }
    }
|}]

module Public_keys_get_existing =
[%graphql
{|
    query get_existing ($public_keys: [String!]!) {
        public_keys(where: {hash: {_in: $public_keys}} ) {
            id
            value
        }
    }
|}]

module Transaction_pool_insert =
[%graphql
{|
mutation transaction_insert(
  $user_commands: [user_commands_insert_input!]!
) {
  insert_user_commands(objects: $user_commands,
  on_conflict: {constraint: user_commands_pkey, update_columns: first_seen}
  ) {
    returning {
      hash
    }
  }
}

|}]
