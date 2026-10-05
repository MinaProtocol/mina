module type S = Ledger_proof_intf.S

include S with type t = Transaction_snark.t

module For_tests : sig
  val mk_dummy_proof :
       statement:
         ( Pasta_bindings.Fp.t
         , ( Mina_wire_types.Currency.M.Amount.V1.t
           , Sgn.Stable.V1.t )
           Mina_wire_types.Signed_poly.V1.t
         , Mina_wire_types.Mina_base_pending_coinbase.M.Stack_versioned.V1.t
         , Mina_base.Fee_excess.Stable.V1.t
         , 'a
         , Mina_state.Local_state.Stable.V1.t )
         Mina_wire_types.Mina_state_snarked_ledger_state.M.Poly.V2.t
    -> fee:Mina_wire_types.Currency.M.Fee.V1.t
    -> prover:Mina_base_import.Public_key.Compressed.Stable.Latest.t
    -> t

  module Cached : sig
    val mk_dummy_proof :
         statement:Mina_state.Snarked_ledger_state.t
      -> fee:Currency.Fee.magnitude
      -> prover:Signature_lib.Public_key.Compressed.t
      -> Cached.t
  end
end
