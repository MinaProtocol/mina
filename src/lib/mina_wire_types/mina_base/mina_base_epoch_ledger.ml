module Poly = struct
  module V1 = struct
    type ('ledger_hash, 'amount) t =
      { hash : 'ledger_hash; total_currency : 'amount }
  end
end
