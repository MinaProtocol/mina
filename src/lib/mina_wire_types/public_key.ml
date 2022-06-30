module Compressed = struct
  module Poly = struct
    type ('field, 'boolean) t = { x : 'field; is_odd : 'boolean }
  end

  type t = (Snark_params.Tick.Field.t, bool) Poly.t
end

type t = Snark_params.Tick.Field.t * Snark_params.Tick.Field.t
