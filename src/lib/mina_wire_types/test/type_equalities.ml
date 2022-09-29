(** Test that wire types and original types can be used interchangeably in the
    eyes of the type system. *)

[@@@warning "-34"]

module WT = Mina_wire_types
open WT.Utils

(** {2 Useful functors for testing} *)

(** {3 Given two modules containing one type, check the types are equal} *)

(** For types with arity 0 *)
module Assert_equal0 (O : S0) (W : S0 with type t = O.t) = struct end

(** For types with arity 1 *)
module Assert_equal1 (O : S1) (W : S1 with type 'a t = 'a O.t) = struct end

(** For types with arity 2 *)
module Assert_equal2 (O : S2) (W : S2 with type ('a, 'b) t = ('a, 'b) O.t) =
struct end

(** {3 Check equality between versioned types of different arities}

   [Assert_equalXVY] checks the equality of two versioned
   types of arity X with version Y *)

module Assert_equal0V1 (O : V1S0) (W : V1S0 with type V1.t = O.V1.t) = struct end

module Assert_equal0V2 (O : V2S0) (W : V2S0 with type V2.t = O.V2.t) = struct end

module Assert_equal1V1 (O : V1S1) (W : V1S1 with type 'a V1.t = 'a O.V1.t) =
struct end

module Assert_equal1V2 (O : V2S1) (W : V2S1 with type 'a V2.t = 'a O.V2.t) =
struct end

module Assert_equal2V1
    (O : V1S2)
    (W : V1S2 with type ('a, 'b) V1.t = ('a, 'b) O.V1.t) =
struct end

module Assert_equal2V2
    (O : V2S2)
    (W : V2S2 with type ('a, 'b) V2.t = ('a, 'b) O.V2.t) =
struct end

module Assert_equal3V1
    (O : V1S3)
    (W : V1S3 with type ('a, 'b, 'c) V1.t = ('a, 'b, 'c) O.V1.t) =
struct end

module Assert_equal3V2
    (O : V2S3)
    (W : V2S3 with type ('a, 'b, 'c) V2.t = ('a, 'b, 'c) O.V2.t) =
struct end

module Assert_equal9V1
    (O : V1S9)
    (W : V1S9
           with type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) V1.t =
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) O.V1.t) =
struct end

module Assert_equal9V2
    (O : V2S9)
    (W : V2S9
           with type ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) V2.t =
             ('a, 'b, 'c, 'd, 'e, 'f, 'g, 'h, 'i) O.V2.t) =
struct end

(** {2 Actual tests}

    Remember than in this library, the [Stable] layer is omitted in versioned
    types, so we have to compare [WT.X.V1.t] and [X.Stable.V1.t] *)

(** Tests for small modules *)
module Misc_tests = struct
  include Assert_equal0V1 (Block_time.Stable) (WT.Block_time)
  include
    Assert_equal0V1
      (Data_hash_lib.State_hash.Stable)
      (WT.Data_hash_lib.State_hash)
  include Assert_equal0V1 (Sgn_type.Sgn.Stable) (WT.Sgn_type.Sgn)
end

module Currency = struct
  module O = Currency
  module W = WT.Currency
  include Assert_equal0V1 (O.Fee.Stable) (W.Fee)
  include Assert_equal0V1 (O.Amount.Stable) (W.Amount)
  include Assert_equal0V1 (O.Balance.Stable) (W.Balance)
end

module Snark_params = struct
  module O = Snark_params
  module W = WT.Snark_params
  include Assert_equal0 (O.Tick.Field) (W.Tick.Field)
  include Assert_equal0 (O.Tock.Field) (W.Tock.Field)
  include Assert_equal0 (O.Tick.Inner_curve) (W.Tick.Inner_curve)
  include Assert_equal0 (O.Tock.Inner_curve) (W.Tock.Inner_curve)
  include Assert_equal0 (O.Tick.Inner_curve.Scalar) (W.Tick.Inner_curve.Scalar)
  include Assert_equal0 (O.Tock.Inner_curve.Scalar) (W.Tock.Inner_curve.Scalar)
end

module Public_key = struct
  module O = Signature_lib.Public_key
  module W = WT.Public_key
  include Assert_equal0V1 (O.Stable) (W)
  include Assert_equal0V1 (O.Compressed.Stable) (W.Compressed)
end

module Mina_numbers = struct
  module O = Mina_numbers
  module W = WT.Mina_numbers
  include Assert_equal0V1 (O.Account_nonce.Stable) (W.Account_nonce)
  include Assert_equal0V1 (O.Global_slot.Stable) (W.Global_slot)
  include Assert_equal0V1 (O.Length.Stable) (W.Length)
  include Assert_equal0V1 (O.Index.Stable) (W.Index)
end

module Pickles_base = struct
  module O = Pickles_base
  module W = WT.Pickles_base
  include Assert_equal0V1 (O.Proofs_verified.Stable) (W.Proofs_verified)
end

module Pickles = struct
  module O = Pickles
  module W = WT.Pickles
  include
    Assert_equal0V2
      (O.Side_loaded.Verification_key.Stable)
      (W.Side_loaded.Verification_key)
  include Assert_equal0V1 (O.Backend.Tick.Field.Stable) (W.Backend.Tick.Field)
  include Assert_equal2 (O.Proof) (W.Proof)
  include
    Assert_equal0V2
      (O.Proof.Proofs_verified_2.Stable)
      (W.Proof.Proofs_verified_2)
end

module Mina_base = struct
  module O = Mina_base
  module W = WT.Mina_base
  include Assert_equal0V1 (O.Signature.Stable) (W.Signature)
  include Assert_equal0V1 (O.Signed_command_memo.Stable) (W.Signed_command_memo)
  include
    Assert_equal0V2
      (O.Signed_command_payload.Common.Stable)
      (W.Signed_command_payload.Common)
  include Assert_equal0V2 (O.Payment_payload.Stable) (W.Payment_payload)
  include Assert_equal0V1 (O.Stake_delegation.Stable) (W.Stake_delegation)
  include
    Assert_equal0V2
      (O.Signed_command_payload.Body.Stable)
      (W.Signed_command_payload.Body)
  include
    Assert_equal0V2 (O.Signed_command_payload.Stable) (W.Signed_command_payload)
  include Assert_equal0V2 (O.Signed_command.Stable) (W.Signed_command)
  include
    Assert_equal0V2
      (O.Signed_command.With_valid_signature.Stable)
      (W.Signed_command.With_valid_signature)
  include
    Assert_equal0V1
      (O.Account_update.Body.Fee_payer.Stable)
      (W.Account_update.Body.Fee_payer)
  include
    Assert_equal0V1
      (O.Account_update.Fee_payer.Stable)
      (W.Account_update.Fee_payer)
  include Assert_equal0V1 (O.Account_id.Digest.Stable) (W.Account_id.Digest)
  include Assert_equal0V2 (O.Account_id.Stable) (W.Account_id)
  include Assert_equal0V1 (O.Token_id.Stable) (W.Token_id)
  include Assert_equal1V1 (O.Zkapp_state.V.Stable) (W.Zkapp_state.V)
  include
    Assert_equal1V1
      (O.Zkapp_basic.Set_or_keep.Stable)
      (W.Zkapp_basic.Set_or_keep)
  include Assert_equal0V1 (O.Zkapp_basic.F.Stable) (W.Zkapp_basic.F)
  include Assert_equal0V2 (O.Permissions.Stable) (W.Permissions)
  include
    Assert_equal0V1 (O.Account.Token_symbol.Stable) (W.Account.Token_symbol)
  include
    Assert_equal0V1
      (O.Account_update.Update.Timing_info.Stable)
      (W.Account_update.Update.Timing_info)
  include
    Assert_equal0V1 (O.Account_update.Update.Stable) (W.Account_update.Update)
  include
    Assert_equal0V1
      (O.Account_update.Body.Events'.Stable)
      (W.Account_update.Body.Events')
  include Assert_equal0V1 (O.Ledger_hash.Stable) (W.Ledger_hash)
  include
    Assert_equal0V1
      (O.Zkapp_command.Valid.Verification_key_hash.Stable)
      (W.Zkapp_command.Valid.Verification_key_hash)

  include
    Assert_equal0V1
      (O.Zkapp_command.Call_forest.Digest.Account_update.Stable)
      (W.Zkapp_command.Call_forest.Digest.Account_update)

  include
    Assert_equal0V1
      (O.Zkapp_command.Call_forest.Digest.Forest.Stable)
      (W.Zkapp_command.Call_forest.Digest.Forest)
  include Assert_equal0V1 (O.Ledger_hash.Stable) (W.Ledger_hash)
  include
    Assert_equal0V1
      (O.Zkapp_precondition.Protocol_state.Epoch_data.Stable)
      (W.Zkapp_precondition.Protocol_state.Epoch_data)
  include
    Assert_equal0V1
      (O.Zkapp_precondition.Protocol_state.Stable)
      (W.Zkapp_precondition.Protocol_state)
  include
    Assert_equal0V2
      (O.Zkapp_precondition.Account.Stable)
      (W.Zkapp_precondition.Account)
  include
    Assert_equal0V1
      (O.Account_update.Account_precondition.Stable)
      (W.Account_update.Account_precondition)
  include
    Assert_equal0V1
      (O.Account_update.Preconditions.Stable)
      (W.Account_update.Preconditions)
  include Assert_equal0V1 (O.Account_update.Body.Stable) (W.Account_update.Body)
  include Assert_equal0V2 (O.Fee_transfer.Single.Stable) (W.Fee_transfer.Single)
  include Assert_equal0V2 (O.Fee_transfer.Stable) (W.Fee_transfer)
  include
    Assert_equal0V1 (O.Coinbase_fee_transfer.Stable) (W.Coinbase_fee_transfer)
  include Assert_equal0V1 (O.Coinbase.Stable) (W.Coinbase)
  include Assert_equal2V1 (O.With_stack_hash.Stable) (W.With_stack_hash)
  include
    Assert_equal3V1
      (O.Zkapp_command.Call_forest.Tree.Stable)
      (W.Zkapp_command.Call_forest.Tree)
  include
    Assert_equal3V1
      (O.Zkapp_command.Call_forest.Stable)
      (W.Zkapp_command.Call_forest)
  include Assert_equal0V2 (O.Control.Stable) (W.Control)
  include Assert_equal0V1 (O.Account_update.Stable) (W.Account_update)
  include Assert_equal0V1 (O.Zkapp_command.Stable) (W.Zkapp_command)
  include Assert_equal0V1 (O.Zkapp_command.Valid.Stable) (W.Zkapp_command.Valid)
  include Assert_equal0V2 (O.User_command.Stable) (W.User_command)
  include Assert_equal0V2 (O.User_command.Valid.Stable) (W.User_command.Valid)
  include
    Assert_equal0V1
      (O.Pending_coinbase.State_stack.Stable)
      (W.Pending_coinbase.State_stack)
  include
    Assert_equal0V1
      (O.Pending_coinbase.Stack_versioned.Stable)
      (W.Pending_coinbase.Stack_versioned)
  include Assert_equal2V1 (O.Fee_excess.Poly.Stable) (W.Fee_excess.Poly)
  include Assert_equal0V1 (O.Fee_excess.Stable) (W.Fee_excess)
  include
    Assert_equal0V2
      (O.Transaction_status.Failure.Stable)
      (W.Transaction_status.Failure)
  include
    Assert_equal0V1
      (O.Transaction_status.Failure.Collection.Stable)
      (W.Transaction_status.Failure.Collection)
  include
    Assert_equal0V1
      (O.Zkapp_command.Transaction_commitment.Stable)
      (W.Zkapp_command.Transaction_commitment)
  include Assert_equal0V1 (O.Call_stack_digest.Stable) (W.Call_stack_digest)
  include Assert_equal0V1 (O.Stack_frame.Digest.Stable) (W.Stack_frame.Digest)
  include Assert_equal0V1 (O.Sok_message.Digest.Stable) (W.Sok_message.Digest)
  include Assert_equal0V1 (O.Fee_with_prover.Stable) (W.Fee_with_prover)
  include Assert_equal0V1 (O.State_body_hash.Stable) (W.State_body_hash)
  include Assert_equal0V1 (O.Frozen_ledger_hash0.Stable) (W.Frozen_ledger_hash0)
end

module One_or_two = struct
  module O = One_or_two
  module W = WT.One_or_two
  include Assert_equal1V1 (O.Stable) (W)
end

module Mina_transaction = struct
  module O = Mina_transaction.Transaction
  module W = WT.Mina_transaction
  include Assert_equal1V2 (O.Poly.Stable) (W.Poly)
  include Assert_equal0V2 (O.Stable) (W)
  include Assert_equal0V2 (O.Valid.Stable) (W.Valid)
end

module Mina_state = struct
  module O = Mina_state
  module W = WT.Mina_state
  include Assert_equal3V1 (O.Registers.Stable) (W.Registers)
  include Assert_equal0V1 (O.Local_state.Stable) (W.Local_state)
end

module Mina_transaction_logic = struct
  module O = Mina_transaction_logic
  module W = WT.Mina_transaction_logic
  include
    Assert_equal9V1
      (O.Zkapp_command_logic.Local_state.Stable)
      (W.Zkapp_command_logic.Local_state)
  include
    Assert_equal0V1
      (O.Zkapp_command_logic.Local_state.Value.Stable)
      (W.Zkapp_command_logic.Local_state.Value)
end

module Transaction_snark = struct
  module O = Transaction_snark
  module W = WT.Transaction_snark
  include Assert_equal0V2 (O.Statement.Stable) (W.Statement)
  include Assert_equal0V2 (O.Statement.With_sok.Stable) (W.Statement.With_sok)
  include Assert_equal0V2 (O.Stable) (W)
end

module Transaction_snark_work = struct
  module O = Transaction_snark_work
  module W = WT.Transaction_snark_work
  include Assert_equal0V2 (O.Statement.Stable) (W.Statement)
end

module Ledger_proof = struct
  module O = Ledger_proof
  module W = WT.Ledger_proof
  include Assert_equal0V2 (O.Stable) (W)
end

module Network_pool = struct
  module O = Network_pool
  module W = WT.Network_pool
  include Assert_equal1V1 (O.Priced_proof.Stable) (W.Priced_proof)
  include
    Assert_equal0V2
      (O.Snark_pool.Diff_versioned.Stable)
      (W.Snark_pool.Diff_versioned)
  include
    Assert_equal0V2
      (O.Transaction_pool.Diff_versioned.Stable)
      (W.Transaction_pool.Diff_versioned)
end

module Consensus = struct
  module O = Consensus
  module W = WT.Consensus
  include Assert_equal0V1 (O.Body_reference.Stable) (W.Body_reference)
end

module Consensus_vrf = struct
  module O = Consensus_vrf
  module W = WT.Consensus_vrf
  include Assert_equal0V1 (O.Output.Truncated.Stable) (W.Output.Truncated)
end
