(**
   This file re-exports the modules containing graphql custom scalars and their serializers.
   These are used by graphql_ppx to automatically use the correct decoder for the fields.
 *)

include Graphql_basic_scalars
include Mina_base_unix.Graphql_scalars
include Mina_block_unix.Graphql_scalars
include Mina_numbers_unix.Graphql_scalars
include Currency_unix.Graphql_scalars
include Signature_lib_unix.Graphql_scalars
include Block_time_unix.Graphql_scalars
include Filtered_external_transition_unix.Graphql_scalars
include Consensus.Graphql_scalars
