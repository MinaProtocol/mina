module Poly = struct
  module V3 = struct
    type 'command t =
      | Command of 'command
      | Fee_transfer of Mina_base.Fee_transfer.V2.t
      | Coinbase of Mina_base.Coinbase.V2.t
  end
end

module V4 = struct
  type t = Mina_base.User_command.V3.t Poly.V3.t
end
