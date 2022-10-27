open Utils

module Types : sig
  module type S = sig
    module Statement : sig
      module Poly : sig
        module V2 : sig
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

      module V2 : sig
        type t =
          ( Mina_base.Ledger_hash.V1.t
          , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
          , Mina_base.Pending_coinbase.Stack_versioned.V1.t
          , Mina_base.Fee_excess.V1.t
          , unit
          , Mina_state.Local_state.V1.t )
          Poly.V2.t
      end

      module With_sok : sig
        module V2 : sig
          type t =
            ( Mina_base.Ledger_hash.V1.t
            , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
            , Mina_base.Pending_coinbase.Stack_versioned.V1.t
            , Mina_base.Fee_excess.V1.t
            , Mina_base.Sok_message.Digest.V1.t
            , Mina_state.Local_state.V1.t )
            Poly.V2.t
        end
      end
    end

    module V2 : S0
  end
end

module type Concrete = sig
  module Statement : sig
    module Poly : sig
      module V2 : sig
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

    module V2 : sig
      type t =
        ( Mina_base.Ledger_hash.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Pending_coinbase.Stack_versioned.V1.t
        , Mina_base.Fee_excess.V1.t
        , unit
        , Mina_state.Local_state.V1.t )
        Poly.V2.t
    end

    module With_sok : sig
      module V2 : sig
        type t =
          ( Mina_base.Ledger_hash.V1.t
          , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
          , Mina_base.Pending_coinbase.Stack_versioned.V1.t
          , Mina_base.Fee_excess.V1.t
          , Mina_base.Sok_message.Digest.V1.t
          , Mina_state.Local_state.V1.t )
          Poly.V2.t
      end
    end
  end

  module Proof : sig
    module V2 : sig
      type t = Pickles.Proof.Proofs_verified_2.V2.t
    end
  end

  module V2 : sig
    type t = { statement : Statement.With_sok.V2.t; proof : Proof.V2.t }
  end
end

module M : sig
  module Statement : sig
    module Poly : sig
      module V2 : sig
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

    module V2 : sig
      type t =
        ( Mina_base.Ledger_hash.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Pending_coinbase.Stack_versioned.V1.t
        , Mina_base.Fee_excess.V1.t
        , unit
        , Mina_state.Local_state.V1.t )
        Poly.V2.t
    end

    module With_sok : sig
      module V2 : sig
        type t =
          ( Mina_base.Ledger_hash.V1.t
          , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
          , Mina_base.Pending_coinbase.Stack_versioned.V1.t
          , Mina_base.Fee_excess.V1.t
          , Mina_base.Sok_message.Digest.V1.t
          , Mina_state.Local_state.V1.t )
          Poly.V2.t
      end
    end
  end

  module V2 : S0
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include Types.S with module Statement = M.Statement and module V2 = M.V2
