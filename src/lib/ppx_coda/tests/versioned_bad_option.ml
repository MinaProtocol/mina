module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          (* "versioned" with invalid option *)
          type t [@@deriving yojson, bin_io, version {n= "not a number"}]
        end
      end
    end
  end
end
