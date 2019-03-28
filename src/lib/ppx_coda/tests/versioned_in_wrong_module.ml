module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t [@@deriving yojson, bin_io, versioned]
        end

        include T
      end
    end
  end
end
