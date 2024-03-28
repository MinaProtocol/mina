module Poly = struct
  module V1 = struct
    type ('ledger_hash, 'amount) t =
      { hash : 'ledger_hash; total_currency : 'amount }
  end
end

module Value = struct
  module V1 = struct
    type t =
      (Mina_base_frozen_ledger_hash0.V1.t, Currency.Amount.V1.t) Poly.V1.t
  end
end
