module V1 = struct
  type ('ledger, 'pending_coinbase_stack, 'local_state) t =
    { ledger : 'ledger
    ; pending_coinbase_stack : 'pending_coinbase_stack
    ; local_state : 'local_state
    }
end

module Blockchain = struct
  module V1 = struct
    type ('ledger, 'pending_coinbase_stack) t =
      { ledger : 'ledger; pending_coinbase_stack : 'pending_coinbase_stack }
  end
end
