module Foo = struct
  module Bar = struct
    module Stable = struct
      module Vx = struct
        module T = struct
          type t [@@deriving version {n= 1}]
        end
      end
    end
  end
end
