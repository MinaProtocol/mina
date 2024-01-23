module Foo = struct
  module Unwrapped = struct
    module Stable = struct
      module V1 = struct
        type t [@@deriving version { wrapped }]
      end
    end
  end
end
