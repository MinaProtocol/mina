module Foo = struct
  module Wrapped = struct
    module Stable = struct
      module V1 = struct
        type t [@@deriving yojson, bin_io, version {wrapped}]
      end
    end
  end
end
