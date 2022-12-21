module V1 = struct
  type ('ledger, 'pending_coinbase_stack, 'local_state) t =
    { ledger : 'ledger
    ; pending_coinbase_stack : 'pending_coinbase_stack
    ; local_state : 'local_state
    }
end
