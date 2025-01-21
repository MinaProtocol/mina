module type S = Ledger_proof_intf.S

module Prod : S with type 'a Poly.t = 'a Transaction_snark.Poly.t

include S with type 'a Poly.t = 'a Transaction_snark.Poly.t

module For_tests : sig
  val mk_dummy_proof : Mina_state.Snarked_ledger_state.t -> t

  val mk_dummy_proof_cached : Mina_state.Snarked_ledger_state.t -> Cached.t
end
