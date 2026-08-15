(* exclude from bisect_ppx to avoid type error on GraphQL modules *)
[@@@coverage exclude_file]

module Scalars = Graphql_lib.Scalars

module Sync_status = [%graphql {|
  query {
    syncStatus
  }
|}]

module Genesis_constants =
[%graphql
{|
  query {
    genesisConstants {
      genesisTimestamp
    }
  }
|}]
