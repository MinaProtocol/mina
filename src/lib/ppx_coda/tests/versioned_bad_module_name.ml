module Foo = struct
  module Bar = struct
    module Stable = struct
      module Vx = struct
        module T = struct
          type t [@@deriving version]
        end
      end
    end
  end
end
