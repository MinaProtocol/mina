open Core_kernel

module Foo = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* List.t is not versioned *)
      type t = int List.t

      let to_latest = Fn.id
    end
  end]
end
