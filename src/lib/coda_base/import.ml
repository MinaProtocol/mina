(* account.ml *)

[%%import
"/src/config.mlh"]

[%%ifndef
consensus_mechanism]

module Signature_lib = Signature_lib_nonconsensus
module Coda_compile_config =
  Coda_compile_config_nonconsensus.Coda_compile_config
module Sgn = Sgn_nonconsensus.Sgn
module Currency = Currency_nonconsensus.Currency
module Random_oracle = Random_oracle_nonconsensus.Random_oracle

[%%endif]

module Public_key = Signature_lib.Public_key
module Private_key = Signature_lib.Private_key
module Signature_keypair = Signature_lib.Keypair
