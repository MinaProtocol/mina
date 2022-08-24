(** Test that wire types and original types can be used interchangeably in the
    eyes of the type system. *)

[@@@warning "-34"]

module WT = Mina_wire_types
open WT.Utils

(* Given two modules containing one type, check the types are equal *)
module Assert_equal0 (O : S0) (W : S0 with type t = O.t) = struct end

module Assert_equal0V1 (O : V1S0) (W : V1S0 with type V1.t = O.V1.t) = struct end
module Assert_equal0V2 (O : V2S0) (W : V2S0 with type V2.t = O.V2.t) = struct end

module Currency = struct
  module O = Currency
  module W = WT.Currency
  include Assert_equal0V1 (O.Fee.Stable) (W.Fee)
  include Assert_equal0V1 (O.Amount.Stable) (W.Amount)
  include Assert_equal0V1 (O.Balance.Stable) (W.Balance)
end

(*
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
  include Assert_equal0V1 (O.Compressed.Stable) (W.Compressed)
  include Assert_equal0V1 (O.Stable) (W)
end
*)

module Mina_numbers = struct
  module O = Mina_numbers
  module W = WT.Mina_numbers
  include Assert_equal0V1 (O.Account_nonce.Stable) (W.Account_nonce)
  include Assert_equal0V1 (O.Global_slot.Stable) (W.Global_slot)
end

(*
module Mina_base = struct
  module O = Mina_base
  module W = WT.Mina_base
  include
    Assert_equal0V1
      (O.Signed_command_payload.Common.Stable)
      (W.Signed_command_payload.Common)
  include
    Assert_equal0V1
      (O.Signed_command_payload.Body.Stable)
      (W.Signed_command_payload.Body)
  include
    Assert_equal0V1 (O.Signed_command_payload.Stable) (W.Signed_command_payload)
  include Assert_equal0V1 (O.Signed_command_memo.Stable) (W.Signed_command_memo)
  include Assert_equal0V1 (O.Signed_command.Stable) (W.Signed_command)
  include Assert_equal0V1 (O.Token_id.Stable) (W.Token_id)
  include Assert_equal0V1 (O.Payment_payload.Stable) (W.Payment_payload)
  include Assert_equal0V1 (O.Stake_delegation.Stable) (W.Stake_delegation)
  include Assert_equal0V1 (O.New_token_payload.Stable) (W.New_token_payload)
  include Assert_equal0V1 (O.New_account_payload.Stable) (W.New_account_payload)
  include Assert_equal0V1 (O.Minting_payload.Stable) (W.Minting_payload)
  include Assert_equal0V1 (O.Signature.Stable) (W.Signature)
end
*)
