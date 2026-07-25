open Core

module Type = struct
  [%%versioned
  module Stable = struct
    module Bad = struct end
  end]
end
