module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        (* type t must be in module T *)
        type t [@@deriving version]
      end
    end
  end
end
