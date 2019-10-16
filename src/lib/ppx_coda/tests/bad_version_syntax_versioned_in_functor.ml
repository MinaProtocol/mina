(* versioned in functor body *)

module Functor (X : sig end) = struct
  module Stable = struct
    [%%versioned
    module V1 = struct
      type t = string
    end]
  end
end
