module Foo = struct
  module Bar = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        (* type name must be t *)
        type not_t [@@deriving version]

        let to_latest = Fn.id
      end
    end]
  end
end
