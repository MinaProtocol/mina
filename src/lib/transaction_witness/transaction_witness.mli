open Core_kernel

module Zkapp_command_segment_witness : sig
  open Mina_base
  open Mina_ledger
  open Currency

  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
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
                With_hash.t
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
        ; init_stack : Pending_coinbase.Stack_versioned.Stable.V1.t
        ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp, yojson]
    end
  end]

  type t =
    { global_first_pass_ledger : Sparse_ledger.t
    ; global_second_pass_ledger : Sparse_ledger.t
    ; local_state_init :
        ( (Token_id.t, Zkapp_command.Call_forest.With_hashes.t) Stack_frame.t
        , ( ( (Token_id.t, Zkapp_command.Call_forest.With_hashes.t) Stack_frame.t
            , Stack_frame.Digest.t )
            With_hash.t
          , Call_stack_digest.t )
          With_stack_hash.t
          list
        , (Amount.t, Sgn.t) Signed_poly.t
        , Sparse_ledger.t
        , bool
        , Kimchi_backend.Pasta.Basic.Fp.t
        , Mina_numbers.Index.t
        , Transaction_status.Failure.Collection.t )
        Mina_transaction_logic.Zkapp_command_logic.Local_state.t
    ; start_zkapp_command :
        ( Zkapp_command.t
        , Kimchi_backend.Pasta.Basic.Fp.t
        , bool )
        Mina_transaction_logic.Zkapp_command_logic.Start_data.t
        list
    ; state_body : Mina_state.Protocol_state.Body.Value.t
    ; init_stack : Pending_coinbase.Stack_versioned.t
    ; block_global_slot : Mina_numbers.Global_slot_since_genesis.t
    }

  val read_all_proofs_from_disk : t -> Stable.Latest.t

  val write_all_proofs_to_disk :
    proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
end

module Poly : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type 'transaction t =
        { transaction : 'transaction
        ; first_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
        ; second_pass_ledger : Mina_ledger.Sparse_ledger.Stable.V2.t
        ; protocol_state_body : Mina_state.Protocol_state.Body.Value.Stable.V2.t
        ; init_stack : Mina_base.Pending_coinbase.Stack_versioned.Stable.V1.t
        ; status : Mina_base.Transaction_status.Stable.V2.t
        ; block_global_slot : Mina_numbers.Global_slot_since_genesis.Stable.V1.t
        }
      [@@deriving sexp, yojson]

      val to_latest : 'transaction t -> 'transaction t

      val map : f_transaction:('a -> 'b) -> 'a t -> 'b t
    end
  end]

  val map : f_transaction:('a -> 'b) -> 'a t -> 'b t
end

[%%versioned:
module Stable : sig
  [@@@no_toplevel_latest_type]

  module V2 : sig
    type t = Mina_transaction.Transaction.Stable.V2.t Poly.Stable.V1.t
    [@@deriving sexp, yojson]
  end
end]

type t = Mina_transaction.Transaction.t Poly.t [@@deriving sexp_of, to_yojson]

val read_all_proofs_from_disk : t -> Stable.Latest.t

val write_all_proofs_to_disk :
  proof_cache_db:Proof_cache_tag.cache_db -> Stable.Latest.t -> t
