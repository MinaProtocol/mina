(* data_hash.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

include Data_hash_lib.Data_hash

[%%else]

include Data_hash_lib_nonconsensus.Data_hash

[%%endif]
