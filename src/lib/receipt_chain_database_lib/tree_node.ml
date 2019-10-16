open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('key, 'value) t = Root | Child of {parent: 'key; value: 'value}
    [@@deriving sexp]
  end
end]

type ('key, 'value) t = ('key, 'value) Stable.Latest.t =
  | Root
  | Child of {parent: 'key; value: 'value}
[@@deriving sexp]
