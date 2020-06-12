(* outside_hash_image.ml *)

[%%import
"/src/config.mlh"]

[%%ifdef
consensus_mechanism]

let t = Snark_params.Tick.Field.zero

[%%else]

let t = Snark_params_nonconsensus.Field.zero

[%%endif]
