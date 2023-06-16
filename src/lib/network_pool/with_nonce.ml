open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = { message : 'a; nonce : int } [@@deriving compare, sexp, yojson]
  end
end]
