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

  module Signed_command_payload : Assert_equal6 = struct
    type ('a, 'b, 'c, 'd, 'e, 'f) orig =
      ('a, 'b, 'c, 'd, 'e, 'f) O.Signed_command_payload.Common.Poly.t

    type ('a, 'b, 'c, 'd, 'e, 'f) wire =
      ('a, 'b, 'c, 'd, 'e, 'f) W.Signed_command_payload.common_poly
  end
end
