open Core_kernel

(* deriving bin_io, but missing deriving version *)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving bin_io]
    end
  end
end
