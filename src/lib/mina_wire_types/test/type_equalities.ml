(** Test that wire types and original types can be used interchangeably in the
    eyes of the type system. *)

[@@@warning "-34"]

module type Assert_equal = sig
  type orig

  type wire = orig
end

module WT = Mina_wire_types

module Currency = struct
  module O = Currency
  module W = WT.Currency

  module _ : Assert_equal = struct
    type orig = O.Fee.t

    type wire = W.fee
  end

  module _ : Assert_equal = struct
    type orig = O.Amount.t

    type wire = W.amount
  end

  module _ : Assert_equal = struct
    type orig = O.Balance.t

    type wire = W.balance
  end
end
