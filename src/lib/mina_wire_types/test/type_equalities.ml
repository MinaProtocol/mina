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

module Snark_params = struct
  module O = Snark_params
  module W = WT.Snark_params

  module _ : Assert_equal = struct
    type orig = O.Tick.Field.t

    type wire = W.tick_field
  end

  module _ : Assert_equal = struct
    type orig = O.Tock.Field.t

    type wire = W.tock_field
  end

  module _ : Assert_equal = struct
    type orig = O.Tick.Inner_curve.t

    type wire = W.tick_inner_curve
  end

  module _ : Assert_equal = struct
    type orig = O.Tock.Inner_curve.t

    type wire = W.tock_inner_curve
  end
end

module Public_key = struct
  module O = Signature_lib.Public_key
  module W = WT.Public_key

  module _ : Assert_equal = struct
    type orig = O.Compressed.t

    type wire = W.compressed
  end

  module _ : Assert_equal = struct
    type orig = O.t

    type wire = W.uncompressed
  end
end
