open Core_kernel

(* deriving bin_io in nested functor body *)

module Functor (X : sig end) (Y : sig
  val _y : int
end) =
struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving bin_io]

      let to_latest = Fn.id
    end
  end]
end
