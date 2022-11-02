module Poly = struct
  module V2 = struct
    type ( 'staged_ledger_hash
         , 'snarked_ledger_hash
         , 'local_state
         , 'time
         , 'body_reference )
         t =
      { staged_ledger_hash : 'staged_ledger_hash
      ; genesis_ledger_hash : 'snarked_ledger_hash
      ; registers :
          ('snarked_ledger_hash, unit, 'local_state) Mina_state_registers.V1.t
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
      , Consensus.Body_reference.V1.t )
      Poly.V2.t
  end
end
