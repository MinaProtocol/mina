open Core_kernel

(* deriving bin_io in functor body *)

module Functor (X : sig end) = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        type t = string [@@deriving bin_io]
      end
    end
  end
end
