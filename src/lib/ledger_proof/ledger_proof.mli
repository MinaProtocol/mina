module type S = Ledger_proof_intf.S

include S with type t = Transaction_snark.t

module For_tests : sig
  val mk_dummy_proof : Mina_state.Snarked_ledger_state.t -> t

  module Cached : sig
    val mk_dummy_proof : Mina_state.Snarked_ledger_state.t -> Cached.t
  end
end
