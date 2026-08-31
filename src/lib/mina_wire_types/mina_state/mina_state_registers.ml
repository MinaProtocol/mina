module V2 = struct
  type ('ledger, 'pending_coinbase_stack, 'local_state, 'fee_excess, 'amount) t =
    { first_pass_ledger : 'ledger
    ; second_pass_ledger : 'ledger
    ; pending_coinbase_stack : 'pending_coinbase_stack
    ; local_state : 'local_state
    ; fee_excess : 'fee_excess
    ; total_currency : 'amount
    ; ledger_after_coinbase : 'ledger
    ; total_supply_after_coinbase : 'amount
    }
end
