open Core_kernel

(* deriving bin_io, version, but not wrapped in %%versioned *)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving bin_io, version]
    end
  end
end
