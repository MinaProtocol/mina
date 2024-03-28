(* versioned in functor body *)

open Core_kernel

module Functor (X : sig end) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = string

      let to_latest = Fn.id
    end
  end]
end
