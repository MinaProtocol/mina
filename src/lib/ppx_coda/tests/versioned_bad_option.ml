module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          (* "version" with invalid option *)
          type t [@@deriving yojson, bin_io, version {unwrapped}]
        end
      end
    end
  end
end
