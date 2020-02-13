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

type _ type_witness =
  | Debug : Debug.t type_witness
  | Prod : Prod.t type_witness

type witnessed_list_with_messages =
  | Witnessed_list_with_messages :
      ('t * Sok_message.t) list * 't type_witness
      -> witnessed_list_with_messages

module For_tests : sig
  val mk_dummy_proof : Transaction_snark.Statement.t -> t
end
