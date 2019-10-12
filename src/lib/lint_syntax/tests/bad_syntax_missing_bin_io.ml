open Core_kernel

(* deriving version, but missing deriving bin_io *)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving version]
    end
  end
end
