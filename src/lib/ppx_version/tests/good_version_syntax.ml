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

(* can omit %%versioned in test module *)

let%test_module "bin_io only" =
  ( module struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = string [@@deriving bin_io]
        end
      end
    end
  end )

let%test_module "version only" =
  ( module struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = string [@@deriving version]

          let _ = version
        end
      end
    end
  end )
