(** Test that wire types and original types can be used interchangeably in the
    eyes of the type system. *)

[@@@warning "-34"]

module WT = Mina_wire_types
open WT.Utils

(* Given two modules containing one type, check the types are equal *)
(* For types with arity 0 *)
module Assert_equal0 (O : S0) (W : S0 with type t = O.t) = struct end

(* For types with arity 1 *)
module Assert_equal1 (O : S1) (W : S1 with type 'a t = 'a O.t) = struct end

(* For types with arity 2 *)
module Assert_equal2 (O : S2) (W : S2 with type ('a, 'b) t = ('a, 'b) O.t) =
struct end

(* Assert_equalXVY checks the equality of two versioned
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
    Assert_equal0V1 (O.Party.Body.Fee_payer.Stable) (W.Party.Body.Fee_payer)
  include Assert_equal0V1 (O.Party.Fee_payer.Stable) (W.Party.Fee_payer)
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
      (O.Party.Update.Timing_info.Stable)
      (W.Party.Update.Timing_info)
  include Assert_equal0V1 (O.Party.Update.Stable) (W.Party.Update)
  include Assert_equal0V1 (O.Party.Body.Events'.Stable) (W.Party.Body.Events')
  include Assert_equal0V1 (O.Ledger_hash.Stable) (W.Ledger_hash)
  include
    Assert_equal0V1
      (O.Parties.Valid.Verification_key_hash.Stable)
      (W.Parties.Valid.Verification_key_hash)
  include
    Assert_equal0V1
      (O.Parties.Call_forest.Digest.Party.Stable)
      (W.Parties.Call_forest.Digest.Party)
  include
    Assert_equal0V1
      (O.Parties.Call_forest.Digest.Forest.Stable)
      (W.Parties.Call_forest.Digest.Forest)
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
      (O.Party.Account_precondition.Stable)
      (W.Party.Account_precondition)
  include Assert_equal0V1 (O.Party.Preconditions.Stable) (W.Party.Preconditions)
  include Assert_equal0V1 (O.Party.Body.Stable) (W.Party.Body)
  include Assert_equal0V2 (O.Fee_transfer.Single.Stable) (W.Fee_transfer.Single)
  include Assert_equal0V2 (O.Fee_transfer.Stable) (W.Fee_transfer)
  include
    Assert_equal0V1 (O.Coinbase_fee_transfer.Stable) (W.Coinbase_fee_transfer)
  include Assert_equal0V1 (O.Coinbase.Stable) (W.Coinbase)
  include Assert_equal2V1 (O.With_stack_hash.Stable) (W.With_stack_hash)
  include
    Assert_equal3V1
      (O.Parties.Call_forest.Tree.Stable)
      (W.Parties.Call_forest.Tree)
  include Assert_equal3V1 (O.Parties.Call_forest.Stable) (W.Parties.Call_forest)
  include Assert_equal0V2 (O.Control.Stable) (W.Control)
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
end
