open Core_kernel

module Type = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int
    end

    module V2 = struct
      type t = bool
    end
  end]
end
