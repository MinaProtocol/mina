open Core_kernel

module Zkapp_command_segment_witness = struct
  open Mina_base
  open Mina_ledger
  open Currency

  (* TODO: Don't serialize all the hashes in here. *)
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t =
        { global_first_pass_ledger : Sparse_ledger.Stable.V3.t
        ; global_second_pass_ledger : Sparse_ledger.Stable.V3.t
        ; local_state_init :
            ( ( Token_id.Stable.V2.t
              , Zkapp_command.Call_forest.With_hashes.Stable.V1.t )
              Stack_frame.Stable.V1.t
            , ( ( ( Token_id.Stable.V2.t
                  , Zkapp_command.Call_forest.With_hashes.Stable.V1.t )
                  Stack_frame.Stable.V1.t
                , Stack_frame.Digest.Stable.V1.t )
                With_hash.Stable.V1.t
              , Call_stack_digest.Stable.V1.t )
              With_stack_hash.Stable.V1.t
              list
            , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
            , Sparse_ledger.Stable.V3.t
            , bool
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
            , Mina_numbers.Index.Stable.V1.t
            , Transaction_status.Failure.Collection.Stable.V1.t )
            Mina_transaction_logic.Zkapp_command_logic.Local_state.Stable.V1.t
        ; start_zkapp_command :
            ( Zkapp_command.Stable.V1.t
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
            , bool )
            Mina_transaction_logic.Zkapp_command_logic.Start_data.Stable.V1.t
            list
        ; state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
        ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
        ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest = Fn.id
    end

    module V1 = struct
      type t =
        { global_first_pass_ledger : Sparse_ledger.Stable.V2.t
        ; global_second_pass_ledger : Sparse_ledger.Stable.V2.t
        ; local_state_init :
            ( ( Token_id.Stable.V2.t
              , Zkapp_command.Call_forest.With_hashes.Stable.V1.t )
              Stack_frame.Stable.V1.t
            , ( ( ( Token_id.Stable.V2.t
                  , Zkapp_command.Call_forest.With_hashes.Stable.V1.t )
                  Stack_frame.Stable.V1.t
                , Stack_frame.Digest.Stable.V1.t )
                With_hash.Stable.V1.t
              , Call_stack_digest.Stable.V1.t )
              With_stack_hash.Stable.V1.t
              list
            , (Amount.Stable.V1.t, Sgn.Stable.V1.t) Signed_poly.Stable.V1.t
            , Sparse_ledger.Stable.V2.t
            , bool
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
            , Mina_numbers.Index.Stable.V1.t
            , Transaction_status.Failure.Collection.Stable.V1.t )
            Mina_transaction_logic.Zkapp_command_logic.Local_state.Stable.V1.t
        ; start_zkapp_command :
            ( Zkapp_command.Stable.V1.t
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
            , bool )
            Mina_transaction_logic.Zkapp_command_logic.Start_data.Stable.V1.t
            list
        ; state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
        ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
        ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      let to_latest (t : t) : V2.t =
        { global_first_pass_ledger =
            Sparse_ledger.Stable.V2.to_latest t.global_first_pass_ledger
        ; global_second_pass_ledger =
            Sparse_ledger.Stable.V2.to_latest t.global_second_pass_ledger
        ; local_state_init =
            { t.local_state_init with
              ledger =
                Sparse_ledger.Stable.V2.to_latest t.local_state_init.ledger
            }
        ; start_zkapp_command = t.start_zkapp_command
        ; state_body = t.state_body
        ; init_stack = t.init_stack
        ; block_global_slot = t.block_global_slot
        }
    end
  end]
end

[%%versioned
module Stable = struct
  module V3 = struct
    type t =
      { transaction : Mina_transaction.Transaction.Stable.V2.t
      ; first_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V3.t
      ; second_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V3.t
      ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
      ; status : Mina_base.Transaction_status.Stable.V2.t
      ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
      }
    [@@deriving sexp, yojson]

    let to_latest = Fn.id
  end

  module V2 = struct
    type t =
      { transaction : Mina_transaction.Transaction.Stable.V2.t
      ; first_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
      ; second_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
      ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
      ; status : Mina_base.Transaction_status.Stable.V2.t
      ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
      }
    [@@deriving sexp, yojson]

    let to_latest (t : t) : V3.t =
      { transaction = t.transaction
      ; protocol_state_body = t.protocol_state_body
      ; init_stack = t.init_stack
      ; status = t.status
      ; block_global_slot = t.block_global_slot
      ; first_pass_ledger =
          Mina_ledger.Sparse_ledger.Stable.V2.to_latest t.first_pass_ledger
      ; second_pass_ledger =
          Mina_ledger.Sparse_ledger.Stable.V2.to_latest t.second_pass_ledger
      }
  end
end]
