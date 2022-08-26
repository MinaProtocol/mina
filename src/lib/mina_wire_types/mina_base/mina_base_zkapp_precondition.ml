module Closed_interval = struct
  module V1 = struct
    type 'a t = { lower : 'a; upper : 'a }
  end
end

module Numeric = struct
  module V1 = struct
    type 'a t = 'a Closed_interval.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
  end
end
