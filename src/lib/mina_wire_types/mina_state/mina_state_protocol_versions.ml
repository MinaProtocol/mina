module Poly = struct
  module V1 = struct
    type ('version, 'proposed) t = { current : 'version; proposed : 'proposed }
  end
end

module Value = struct
  module V1 = struct
    type t = (Protocol_version.V2.t, Protocol_version.V2.t option) Poly.V1.t
  end
end
