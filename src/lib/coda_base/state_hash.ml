(* state_hash.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

include Data_hash_lib.State_hash

[%%else]

include Data_hash_lib_nonconsensus.State_hash

[%%endif]
