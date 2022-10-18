module Local_state = struct
  module V1 = struct
    type ( 'stack_frame
         , 'call_stack
         , 'token_id
         , 'signed_amount
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
      ; excess : 'signed_amount
      ; supply_increase : 'signed_amount
      ; ledger : 'ledger
      ; success : 'bool
      ; account_update_index : 'length
      ; failure_status_tbl : 'failure_status_tbl
      }
  end

  module Value = struct
    module V1 = struct
      type t =
        ( Mina_base.Stack_frame.Digest.V1.t
        , Mina_base.Call_stack_digest.V1.t
        , Mina_base.Token_id.V1.t
        , (Currency.Amount.V1.t, Sgn_type.Sgn.V1.t) Signed_poly.V1.t
        , Mina_base.Ledger_hash.V1.t
        , bool
        , Mina_base.Zkapp_command.Transaction_commitment.V1.t
        , Mina_numbers.Index.V1.t
        , Mina_base.Transaction_status.Failure.Collection.V1.t )
        V1.t
    end
  end
end
