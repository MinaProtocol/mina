open Core_kernel

(* deriving version and bin_io both appear; OK outside functor body *)

module Stable = struct
  module V1 = struct
    module T = struct
      type t = int [@@deriving bin_io, version]
    end
  end
end

(* don't need invariants to hold inside test module *)

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
