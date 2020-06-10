open Core_kernel

(* (generated) deriving version and bin_io both appear; OK outside functor body *)

[%%versioned
module Stable = struct
  module V1 = struct
    type t = int

    let to_latest = Fn.id
  end
end]

(* deliberately unversioned *)
type t = int [@@bin_io_unversioned]
