open Core_kernel

module Foo = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      (* can't version arrow type *)
      type t = int -> string

      let to_lateset = Fn.id
    end
  end]
end
