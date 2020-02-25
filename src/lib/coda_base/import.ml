(* account.ml *)

[%%import
"/src/config.mlh"]

[%%ifndef
consensus_mechanism]

module Signature_lib = Signature_lib_nonconsensus

[%%endif]

module Public_key = Signature_lib.Public_key
module Private_key = Signature_lib.Private_key
module Signature_keypair = Signature_lib.Keypair
