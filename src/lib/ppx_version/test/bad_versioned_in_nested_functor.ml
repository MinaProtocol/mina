open Core_kernel

(* deriving bin_io in nested functor body *)

module Functor (X : sig type t end) (Y : sig
  val _y : int
end) =
struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string [@@deriving bin_io]

      type x = X.t

      let to_latest = Fn.id
    end
  end]
end