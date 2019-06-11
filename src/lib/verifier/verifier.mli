[%%import "../../config.mlh"]

module Prod :
  Coda_intf.Verifier_intf with type ledger_proof = Ledger_proof.Prod.t

module Dummy :
  Coda_intf.Verifier_intf
  with type t = unit
   and type ledger_proof = Ledger_proof.Debug.t

[%%if proof_level = "full"]

include module type of Prod

[%%else]

include module type of Dummy

[%%endif]
