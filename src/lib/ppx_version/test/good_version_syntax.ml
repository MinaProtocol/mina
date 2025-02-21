open Core_kernel

(* (generated) deriving version and bin_io both appear; OK outside functor body *)

module M1 = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = int

      let to_latest = Fn.id
    end
  end]
end

(* version with an argument *)
module M = struct
  module V1 = struct
    module T = struct
      type query = Core_kernel.Int.Stable.V1.t
      [@@deriving bin_io, version { rpc }]
    end
  end
end

(* deliberately unversioned *)
type t = int [@@bin_io_unversioned]
