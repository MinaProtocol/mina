open Core_kernel

module Poly = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type ('a, 'b) t = Poly of 'a * 'b
        [@@deriving bin_io, yojson, version]
      end

      include T
    end
  end
end

module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = (string, int) Poly.Stable.V1.t
          [@@deriving yojson, bin_io, version]
        end

        include T
      end
    end
  end
end
