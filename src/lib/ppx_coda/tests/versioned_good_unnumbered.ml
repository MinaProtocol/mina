open Core_kernel

module Foo = struct
  module Bar = struct
    module Stable = struct
      module V1 = struct
        module T = struct
          type t = int [@@deriving yojson, bin_io, version {unnumbered}]
        end

        include T
      end
    end
  end
end

module type Quux = sig
  type t = Int.t [@@deriving version {unnumbered}]
end
