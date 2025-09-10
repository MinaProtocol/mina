open Core_kernel

module Foo = struct
  module Bar = struct
    type t = int [@@deriving bin_io]
  end

  type t = string [@@deriving bin_io]

  type t' = string [@@deriving bin_io]

  module Quux = struct
    type t = int [@@deriving bin_io]
  end
end

type t = char [@@deriving bin_io]
