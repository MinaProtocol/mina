open Core_kernel

module Foo = struct
  module Bar = struct
    [%%versioned
    module Stable = struct
      module Vx = struct
        type t = int

        let to_latest = Fn.id
      end
    end]
  end
end
