[%%import "../../config.mlh"]

open Coda_base

module type S = Ledger_proof_intf.S

module Prod : S with type t = Transaction_snark.t

module Debug :
  S
  with type t = Transaction_snark.Statement.t * Sok_message.Digest.Stable.V1.t

[%%if proof_level = "full"]

include S with type t = Prod.t

[%%else]

include S with type t = Debug.t

[%%endif]

module For_tests : sig
  val mk_dummy_proof : Transaction_snark.Statement.t -> t
end
