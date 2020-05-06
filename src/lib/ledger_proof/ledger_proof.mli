[%%import "../../config.mlh"]

module type S = Ledger_proof_intf.S

module Prod : S with type t = Transaction_snark.t

module Debug :
  S
  with type t = Transaction_snark.Statement.t * Coda_base.Sok_message.Digest.t

[%%if proof_level = "full"]

include S with type t = Prod.t

[%%else]

include S with type t = Debug.t

[%%endif]

type _ type_witness =
  | Debug : Debug.t type_witness
  | Prod : Prod.t type_witness

type with_witness = With_witness : 't * 't type_witness -> with_witness

module For_tests : sig
  val mk_dummy_proof : Transaction_snark.Statement.t -> t
end
