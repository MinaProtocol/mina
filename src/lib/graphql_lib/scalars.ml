(**
   This file re-exports the modules containing graphql custom scalars and their serializers.
   These are used by graphql_ppx to automatically use the correct decoder for the fields.
 *)

include Graphql_basic_scalars
include Mina_base_graphql.Graphql_scalars
include Mina_block_graphql.Graphql_scalars
include Mina_numbers_graphql.Graphql_scalars
include Currency_graphql.Graphql_scalars
include Signature_lib_graphql.Graphql_scalars
include Block_time_graphql.Graphql_scalars
include Filtered_external_transition_graphql.Graphql_scalars
include Consensus_graphql.Graphql_scalars
include Mina_transaction_graphql.Graphql_scalars
include Snark_params_graphql.Graphql_scalars
include Data_hash_lib_graphql.Graphql_scalars
include Pickles_graphql.Graphql_scalars
