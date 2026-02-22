module Poly = struct
  module V2 = struct
    type ( 'staged_ledger_hash
         , 'snarked_ledger_hash
         , 'local_state
         , 'time
         , 'body_reference
         , 'signed_amount
         , 'pending_coinbase_stack
         , 'fee_excess
         , 'sok_digest )
         t =
      { staged_ledger_hash : 'staged_ledger_hash
      ; genesis_ledger_hash : 'snarked_ledger_hash
      ; ledger_proof_statement :
          ( 'snarked_ledger_hash
          , 'signed_amount
          , 'pending_coinbase_stack
          , 'fee_excess
          , 'sok_digest
          , 'local_state )
          Mina_state_snarked_ledger_state.Poly.V2.t
      ; timestamp : 'time
      ; body_reference : 'body_reference
      }
  end
end

module Value = struct
  module V2 = struct
    type t =
      ( Mina_base.Staged_ledger_hash.V1.t
      , Mina_base.Frozen_ledger_hash.V1.t
      , Mina_state_local_state.V1.t
      , Block_time.V1.t
      , Consensus.Body_reference.V1.t
      , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      , Mina_base.Pending_coinbase.Stack_versioned.V1.t
      , Mina_base.Fee_excess.V1.t
      , unit )
      Poly.V2.t
  end
end
