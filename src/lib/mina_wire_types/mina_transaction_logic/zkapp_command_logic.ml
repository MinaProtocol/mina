module Local_state = struct
  module V1 = struct
    type ( 'stack_frame
         , 'call_stack
         , 'token_id
         , 'excess
         , 'ledger
         , 'bool
         , 'comm
         , 'length
         , 'failure_status_tbl )
         t =
      { stack_frame : 'stack_frame
      ; call_stack : 'call_stack
      ; transaction_commitment : 'comm
      ; full_transaction_commitment : 'comm
      ; token_id : 'token_id
      ; excess : 'excess
      ; ledger : 'ledger
      ; success : 'bool
      ; account_update_index : 'length
      ; failure_status_tbl : 'failure_status_tbl
      }
  end
end
