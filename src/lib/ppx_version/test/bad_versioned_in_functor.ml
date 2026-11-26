(* versioned in functor body *)

open Core_kernel

module Functor (X : sig type x end) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string

      type x = X.x
      let to_latest = Fn.id
    end
  end]
end
