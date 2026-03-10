module Constant = struct
  module Hex64 = struct
    type t = Int64.t
  end

  type 'n t = (Hex64.t, 'n) Pickles_types.Vector.t
end
