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

(* Assert_equalXVY checks the equality of two versioned
   types of arity X with version Y *)
module Assert_equal0V1 (O : V1S0) (W : V1S0 with type V1.t = O.V1.t) = struct end

module Assert_equal0V2 (O : V2S0) (W : V2S0 with type V2.t = O.V2.t) = struct end

module Assert_equal1V1 (O : V1S1) (W : V1S1 with type 'a V1.t = 'a O.V1.t) =
struct end

module Assert_equal1V2 (O : V2S1) (W : V2S1 with type 'a V2.t = 'a O.V2.t) =
struct end

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
    Assert_equal0V1 (O.Party.Body.Fee_payer.Stable) (W.Party.Body.Fee_payer)
  include Assert_equal0V1 (O.Party.Fee_payer.Stable) (W.Party.Fee_payer)
  include Assert_equal0V1 (O.Account_id.Digest.Stable) (W.Account_id.Digest)
  include Assert_equal0V1 (O.Token_id.Stable) (W.Token_id)
  include Assert_equal1V1 (O.Zkapp_state.V.Stable) (W.Zkapp_state.V)
  include
    Assert_equal1V1
      (O.Zkapp_basic.Set_or_keep.Stable)
      (W.Zkapp_basic.Set_or_keep)
  include Assert_equal0V2 (O.Permissions.Stable) (W.Permissions)
  include
    Assert_equal0V1 (O.Account.Token_symbol.Stable) (W.Account.Token_symbol)
  include
    Assert_equal0V1
      (O.Party.Update.Timing_info.Stable)
      (W.Party.Update.Timing_info)
  include Assert_equal0V1 (O.Party.Update.Stable) (W.Party.Update)
  (* To port from V1 to V2

     include Assert_equal0V1 (O.New_token_payload.Stable) (W.New_token_payload)
     include Assert_equal0V1 (O.New_account_payload.Stable) (W.New_account_payload)
     include Assert_equal0V1 (O.Minting_payload.Stable) (W.Minting_payload)
  *)
end
