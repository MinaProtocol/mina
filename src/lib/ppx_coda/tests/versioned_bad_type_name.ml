module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          (* type name must be t *)
          type not_t [@@deriving version]
        end

        include T
      end
    end
  end
end
