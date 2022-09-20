module Statement = struct
  module Poly = struct
    module V2 = struct
      type ( 'ledger_hash
           , 'amount
           , 'pending_coinbase
           , 'fee_excess
           , 'sok_digest
           , 'local_state )
           t =
        { source :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state )
            Mina_state.Registers.V1.t
        ; target :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state )
            Mina_state.Registers.V1.t
        ; supply_increase : 'amount
        ; fee_excess : 'fee_excess
        ; sok_digest : 'sok_digest
        }
    end
  end

  module V2 = struct
    type t =
      ( Mina_base.Ledger_hash.V1.t
      , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      , Mina_base.Pending_coinbase.Stack_versioned.V1.t
      , Mina_base.Fee_excess.V1.t
      , unit
      , Mina_state.Local_state.V1.t )
      Poly.V2.t
  end
end
