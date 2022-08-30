module Poly = struct
  module V2 = struct
    type 'command t =
      | Command of 'command
      | Fee_transfer of Mina_base.Fee_transfer.V2.t
      | Coinbase of Mina_base.Coinbase.V1.t
  end
end
