module Constant = struct
  module Hex64 = struct
    type t = Int64.t
  end

  module Make (N : Pickles_types.Vector.Nat_intf) = struct
    module A = Pickles_types.Vector.With_length (N)

    type t = Hex64.t A.t
  end
end
