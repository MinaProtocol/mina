open Core_kernel

(* a GADT type with unversioned result types (List.t and Array.t are from Core_kernel, not versioned) *)
module Stable = struct
  module V1 = struct
    module T = struct
      type ('a, 'b) t =
        | Foo : int -> (int, int List.t) t
        | Bar : string -> (string, string Array.t) t
      [@@deriving version]
    end
  end
end
