open Core_kernel

(* deriving version in functor body *)

module Functor (X : sig end) = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving version]
      end
    end
  end
end
