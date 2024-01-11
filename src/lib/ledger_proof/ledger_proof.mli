module type S = Ledger_proof_intf.S

module Prod : S with type t = Transaction_snark.t

include S with type t = Prod.t

module For_tests : sig
  val mk_dummy_proof : Mina_state.Snarked_ledger_state.t -> t
end
