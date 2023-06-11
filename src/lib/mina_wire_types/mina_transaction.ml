module Poly = struct
  module V2 = struct
    type 'command t =
      | Command of 'command
      | Fee_transfer of Mina_base.Fee_transfer.V2.t
      | Coinbase of Mina_base.Coinbase.V1.t
  end
end

module V2 = struct
  type t = Mina_base.User_command.V2.t Poly.V2.t
end

module Valid = struct
  module V2 = struct
    type t = Mina_base.User_command.Valid.V2.t Poly.V2.t
  end
end
