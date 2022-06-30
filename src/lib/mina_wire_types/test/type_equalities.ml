(** Test that wire types and original types can be used interchangeably in the
    eyes of the type system. *)

[@@@warning "-34"]

module type Assert_equal0 = sig
  type orig

  type wire = orig
end

module type Assert_equal6 = sig
  type ('a, 'b, 'c, 'd, 'e, 'f) orig

  type ('a, 'b, 'c, 'd, 'e, 'f) wire = ('a, 'b, 'c, 'd, 'e, 'f) orig
end

module WT = Mina_wire_types

module Currency = struct
  module O = Currency
  module W = WT.Currency

  module _ : Assert_equal0 = struct
    type orig = O.Fee.t

    type wire = W.fee
  end

  module _ : Assert_equal0 = struct
    type orig = O.Amount.t

    type wire = W.amount
  end

  module _ : Assert_equal0 = struct
    type orig = O.Balance.t

    type wire = W.balance
  end
end

module Snark_params = struct
  module O = Snark_params
  module W = WT.Snark_params

  module _ : Assert_equal0 = struct
    type orig = O.Tick.Field.t

    type wire = W.tick_field
  end

  module _ : Assert_equal0 = struct
    type orig = O.Tock.Field.t

    type wire = W.tock_field
  end

  module _ : Assert_equal0 = struct
    type orig = O.Tick.Inner_curve.t

    type wire = W.tick_inner_curve
  end

  module _ : Assert_equal0 = struct
    type orig = O.Tock.Inner_curve.t

    type wire = W.tock_inner_curve
  end

  module _ : Assert_equal0 = struct
    type orig = O.Tick.Inner_curve.Scalar.t

    type wire = W.tick_inner_curve_scalar
  end

  module _ : Assert_equal0 = struct
    type orig = O.Tock.Inner_curve.Scalar.t

    type wire = W.tock_inner_curve_scalar
  end
end

module Public_key = struct
  module O = Signature_lib.Public_key
  module W = WT.Public_key

  module _ : Assert_equal0 = struct
    type orig = O.Compressed.t

    type wire = W.compressed
  end

  module _ : Assert_equal0 = struct
    type orig = O.t

    type wire = W.uncompressed
  end
end

module Mina_base = struct
  module O = Mina_base
  module W = WT.Mina_base

  module Signed_command_payload_common : Assert_equal0 = struct
    type orig = O.Signed_command_payload.Common.t

    type wire = W.Signed_command_payload.common
  end

  module Signed_command_payload_body : Assert_equal0 = struct
    type orig = O.Signed_command_payload.Body.t

    type wire = W.Signed_command_payload.body
  end

  module Signed_command_payload : Assert_equal0 = struct
    type orig = O.Signed_command_payload.t

    type wire = W.Signed_command_payload.t
  end

  module Signed_command_memo : Assert_equal0 = struct
    type orig = O.Signed_command_memo.t

    type wire = W.Signed_command_memo.t
  end

  module Signed_command : Assert_equal0 = struct
    type orig = O.Signed_command.t

    type wire = W.Signed_command.t
  end

  module Token_id : Assert_equal0 = struct
    type orig = O.Token_id.t

    type wire = W.Token_id.t
  end

  module Payment_payload : Assert_equal0 = struct
    type orig = O.Payment_payload.t

    type wire = W.Payment_payload.t
  end

  module Stake_delegation : Assert_equal0 = struct
    type orig = O.Stake_delegation.t

    type wire = W.Stake_delegation.t
  end

  module New_token_payload : Assert_equal0 = struct
    type orig = O.New_token_payload.t

    type wire = W.New_token_payload.t
  end

  module New_account_payload : Assert_equal0 = struct
    type orig = O.New_account_payload.t

    type wire = W.New_account_payload.t
  end

  module Minting_payload : Assert_equal0 = struct
    type orig = O.Minting_payload.t

    type wire = W.Minting_payload.t
  end

  module Signature : Assert_equal0 = struct
    type orig = O.Signature.t

    type wire = W.Signature.t
  end
end

module Mina_numbers = struct
  module O = Mina_numbers
  module W = WT.Mina_numbers

  module Account_nonce : Assert_equal0 = struct
    type orig = O.Account_nonce.t

    type wire = W.Account_nonce.t
  end

  module Global_slot : Assert_equal0 = struct
    type orig = O.Global_slot.t

    type wire = W.Global_slot.t
  end
end
