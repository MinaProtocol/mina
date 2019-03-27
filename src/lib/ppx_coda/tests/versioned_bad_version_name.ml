module Foo = struct
  module Bar = struct
    module Stable = struct
      (* module name can't have 0 as first digit after V *)
      module V01 = struct
        module T = struct
          type t [@@deriving versioned]
        end
      end
    end
  end
end
