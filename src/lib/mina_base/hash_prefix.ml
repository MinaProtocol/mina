(* hash_prefix.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

include Hash_prefix_states

[%%else]

include Hash_prefix_states_nonconsensus.Hash_prefix_states

[%%endif]
