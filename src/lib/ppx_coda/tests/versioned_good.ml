open Core_kernel

module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = int [@@deriving yojson, bin_io, version]
        end

        include T
      end
    end
  end
end

module type Some_intf = sig
  type t = Quux | Zzz [@@deriving bin_io, version]
end
