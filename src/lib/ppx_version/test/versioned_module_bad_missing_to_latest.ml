open Core_kernel

module Type = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = int

      let to_latest = Fn.id
    end

    module V1 = struct
      type t = bool
    end
  end]
end
