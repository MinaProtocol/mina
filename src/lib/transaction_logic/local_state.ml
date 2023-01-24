open Core_kernel
open Mina_base

[%%versioned
module Stable = struct
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
          ( 'stack_frame
          , 'call_stack
          , 'token_id
          , 'signed_amount
          , 'ledger
          , 'bool
          , 'comm
          , 'length
          , 'failure_status_tbl )
          Mina_wire_types.Mina_transaction_logic.Zkapp_command_logic.Local_state
          .V1
          .t =
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
      ; will_succeed : 'bool
      }
    [@@deriving compare, equal, hash, sexp, yojson, fields, hlist]
  end
end]

let typ stack_frame call_stack token_id excess supply_increase ledger bool comm
    length failure_status_tbl =
  Pickles.Impls.Step.Typ.of_hlistable
    [ stack_frame
    ; call_stack
    ; comm
    ; comm
    ; token_id
    ; excess
    ; supply_increase
    ; ledger
    ; bool
    ; length
    ; failure_status_tbl
    ; bool
    ]
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
    ~value_of_hlist:of_hlist

module Value = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Mina_base.Stack_frame.Digest.Stable.V1.t
        , Mina_base.Call_stack_digest.Stable.V1.t
        , Token_id.Stable.V2.t
        , ( Currency.Amount.Stable.V1.t
          , Sgn.Stable.V1.t )
          Currency.Signed_poly.Stable.V1.t
        , Ledger_hash.Stable.V1.t
        , bool
        , Zkapp_command.Transaction_commitment.Stable.V1.t
        , Mina_numbers.Index.Stable.V1.t
        , Transaction_status.Failure.Collection.Stable.V1.t )
        Stable.V1.t
      [@@deriving equal, compare, hash, yojson, sexp]

      let to_latest = Fn.id
    end
  end]
end

module Checked = struct
  open Pickles.Impls.Step

  type t =
    ( Stack_frame.Digest.Checked.t
    , Call_stack_digest.Checked.t
    , Token_id.Checked.t
    , Currency.Amount.Signed.Checked.t
    , Ledger_hash.var
    , Boolean.var
    , Zkapp_command.Transaction_commitment.Checked.t
    , Mina_numbers.Index.Checked.t
    , unit )
    Stable.Latest.t
end
