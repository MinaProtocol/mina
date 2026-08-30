open Utils

module Types = struct
  module type S = sig
    module Poly : sig
      module V3 : sig
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
              , 'local_state
              , 'fee_excess )
              Mina_state_registers.V2.t
          ; target :
              ( 'ledger_hash
              , 'pending_coinbase
              , 'local_state
              , 'fee_excess )
              Mina_state_registers.V2.t
          ; connecting_ledger_left : 'ledger_hash
          ; connecting_ledger_right : 'ledger_hash
          ; supply_increase : 'amount
          ; sok_digest : 'sok_digest
          }
      end
    end

    module V3 : sig
      type t =
        ( Mina_base.Frozen_ledger_hash.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Pending_coinbase.Stack_versioned.V1.t
        , Mina_base.Fee_excess.V2.t
        , unit
        , Mina_state_local_state.V1.t )
        Poly.V3.t
    end

    module With_sok : sig
      module V3 : sig
        type t =
          ( Mina_base.Ledger_hash.V1.t
          , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
          , Mina_base.Pending_coinbase.Stack_versioned.V1.t
          , Mina_base.Fee_excess.V2.t
          , Mina_base.Sok_message.Digest.V1.t
          , Mina_state_local_state.V1.t )
          Poly.V3.t
      end
    end
  end
end

module type Concrete = sig
  module Poly : sig
    module V3 : sig
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
            , 'local_state
            , 'fee_excess )
            Mina_state_registers.V2.t
        ; target :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state
            , 'fee_excess )
            Mina_state_registers.V2.t
        ; connecting_ledger_left : 'ledger_hash
        ; connecting_ledger_right : 'ledger_hash
        ; supply_increase : 'amount
        ; sok_digest : 'sok_digest
        }
    end
  end

  module V3 : sig
    type t =
      ( Mina_base.Frozen_ledger_hash.V1.t
      , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      , Mina_base.Pending_coinbase.Stack_versioned.V1.t
      , Mina_base.Fee_excess.V2.t
      , unit
      , Mina_state_local_state.V1.t )
      Poly.V3.t
  end

  module With_sok : sig
    module V3 : sig
      type t =
        ( Mina_base.Ledger_hash.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Pending_coinbase.Stack_versioned.V1.t
        , Mina_base.Fee_excess.V2.t
        , Mina_base.Sok_message.Digest.V1.t
        , Mina_state_local_state.V1.t )
        Poly.V3.t
    end
  end
end

module M = struct
  module Poly = struct
    module V3 = struct
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
            , 'local_state
            , 'fee_excess )
            Mina_state_registers.V2.t
        ; target :
            ( 'ledger_hash
            , 'pending_coinbase
            , 'local_state
            , 'fee_excess )
            Mina_state_registers.V2.t
        ; connecting_ledger_left : 'ledger_hash
        ; connecting_ledger_right : 'ledger_hash
        ; supply_increase : 'amount
        ; sok_digest : 'sok_digest
        }
    end
  end

  module V3 = struct
    type t =
      ( Mina_base.Frozen_ledger_hash.V1.t
      , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
      , Mina_base.Pending_coinbase.Stack_versioned.V1.t
      , Mina_base.Fee_excess.V2.t
      , unit
      , Mina_state_local_state.V1.t )
      Poly.V3.t
  end

  module With_sok = struct
    module V3 = struct
      type t =
        ( Mina_base.Ledger_hash.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Pending_coinbase.Stack_versioned.V1.t
        , Mina_base.Fee_excess.V2.t
        , Mina_base.Sok_message.Digest.V1.t
        , Mina_state_local_state.V1.t )
        Poly.V3.t
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig)
    (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
