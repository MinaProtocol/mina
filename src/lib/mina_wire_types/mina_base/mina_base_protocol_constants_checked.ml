module Value = struct
  module V1 = struct
    type t =
      ( Mina_numbers.Length.V1.t
      , Mina_numbers.Length.V1.t
      , Block_time.V1.t )
      Genesis_constants.Protocol.Poly.V1.t
  end
end
