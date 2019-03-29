[%%import "../../config.mlh"]

[%%if proof_level = "full"]

type t = Transaction_snark.t

[%%else]

type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t

[%%endif]

include Protocols.Coda_pow.Ledger_proof_intf
  with type t := t
   and type statement = Transaction_snark.Statement.t
   and type sok_digest := Sok_message.Digest.t
   and type ledger_hash := Frozen_ledger_hash.t
   and type proof := Proof.t
