module Poly = struct
  module V2 = struct
    type ('u, 's) t = Signed_command of 'u | Parties of 's
  end
end

module V2 = struct
  type t = (Mina_base_signed_command.V2.t, Mina_base_parties.V1.t) Poly.V2.t
end

module Valid = struct
  module V2 = struct
    type t =
      ( Mina_base_signed_command.With_valid_signature.V2.t
      , Mina_base_parties.Valid.V1.t )
      Poly.V2.t
  end
end
