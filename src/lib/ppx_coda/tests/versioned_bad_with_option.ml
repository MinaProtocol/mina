module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        (* "versioned" with option; missing T module *)
        type t [@@deriving yojson, bin_io, versioned [1]]
      end
    end
  end
end
