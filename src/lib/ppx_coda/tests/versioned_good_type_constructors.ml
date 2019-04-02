open Core_kernel

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving yojson, bin_io, version]
    end

    include T
  end
end

module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = Stable.V1.t option [@@deriving yojson, bin_io, version]
        end

        include T
      end

      module V2 = struct
        module T = struct
          type t = Stable.V1.t option [@@deriving yojson, bin_io, version]
        end

        include T
      end

      module V3 = struct
        module T = struct
          type t = Stable.V1.t option [@@deriving yojson, bin_io, version]
        end

        include T
      end
    end
  end
end
