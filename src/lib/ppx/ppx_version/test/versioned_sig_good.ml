open Core_kernel

module Good = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = int

      let to_latest = Fn.id
    end

    module V1 = struct
      type t = string

      let to_latest = String.length
    end
  end]

  (* make sure t is an int *)
  let is_42 t = Int.( = ) t 42
end
