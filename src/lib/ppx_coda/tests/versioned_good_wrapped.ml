module Foo = struct
  module Wrapped = struct
    module Stable = struct
      module V1 = struct
        type t = string [@@deriving version {wrapped}]
      end
    end
  end
end
