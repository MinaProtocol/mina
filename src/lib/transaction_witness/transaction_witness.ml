open Core_kernel

module Parties_segment_witness = struct
  open Mina_base
  open Mina_ledger
  open Currency

  (* TODO: Don't serialize all the hashes in here. *)
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { global_ledger : Sparse_ledger.Stable.V2.t
        ; local_state_init :
            ( ( Token_id.Stable.V1.t
              , unit Parties.Call_forest.With_hashes.Stable.V1.t )
              Stack_frame.Stable.V1.t
            , ( ( ( Token_id.Stable.V1.t
                  , unit Parties.Call_forest.With_hashes.Stable.V1.t )
                  Stack_frame.Stable.V1.t
                , Stack_frame.Digest.Stable.V1.t )
                With_hash.Stable.V1.t
              , Call_stack_digest.Stable.V1.t )
              With_stack_hash.Stable.V1.t
              list
            , Token_id.Stable.V1.t
            , Amount.Stable.V1.t
            , Sparse_ledger.Stable.V2.t
            , bool
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
            , Transaction_status.Failure.Collection.Stable.V1.t )
            Mina_transaction_logic.Parties_logic.Local_state.Stable.V1.t
        ; start_parties :
            ( Parties.Stable.V1.t
            , Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t )
            Mina_transaction_logic.Parties_logic.Start_data.Stable.V1.t
            list
        ; state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
        ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
        }
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]
end

[%%versioned
module Stable = struct
  module V2 = struct
    type t =
      { transaction : Mina_transaction.Transaction.Stable.V2.t
      ; ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
      ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
      ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
      ; status : Mina_base.Transaction_status.Stable.V2.t
      }
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end
end]
