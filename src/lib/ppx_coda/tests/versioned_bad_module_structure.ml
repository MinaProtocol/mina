module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        (* type t must be in module T *)
        type t [@@deriving versioned]
      end
    end
  end
end
