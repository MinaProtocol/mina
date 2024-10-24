module Poly = struct
  module V2 = struct
    type ('u, 's) t = Signed_command of 'u | Zkapp_command of 's
  end
end

module V2 = struct
  type t =
    (Mina_base_signed_command.V2.t, Mina_base_zkapp_command.V1.t) Poly.V2.t
end
