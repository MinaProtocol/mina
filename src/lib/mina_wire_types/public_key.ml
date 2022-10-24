module Compressed = struct
  module Poly = struct
    module V1 = struct
      type ('field, 'boolean) t = { x : 'field; is_odd : 'boolean }
    end
  end

  module V1 = struct
    type t = (Snark_params.Step.Field.t, bool) Poly.V1.t
  end
end

module V1 = struct
  type t = Snark_params.Step.Field.t * Snark_params.Step.Field.t
end
