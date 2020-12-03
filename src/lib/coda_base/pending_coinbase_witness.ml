open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      {pending_coinbases: Pending_coinbase.Stable.V1.t; is_new_stack: bool}
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end
end]
