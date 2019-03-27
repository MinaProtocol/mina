module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          (* "versioned" with option (in case we use it) *)
          type t [@@deriving yojson, bin_io, versioned [1]]
        end

        include T
      end
    end
  end
end
