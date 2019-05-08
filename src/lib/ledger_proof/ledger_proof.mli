[%%import "../../config.mlh"]

open Coda_base

module type S =
  Protocols.Coda_pow.Ledger_proof_intf
  with type statement := Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t

module Prod : S with type t = Transaction_snark.t

module Debug :
  S
  with type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t

[%%if proof_level = "full"]

include S with type t = Prod.t

[%%else]

include S with type t = Debug.t

[%%endif]
