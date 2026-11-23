open Core_kernel

[%%versioned
module Stable = struct
  module V3 = struct
    type t = { pending_coinbases : Pending_coinbase.Stable.V3.t }
    [@@deriving sexp, to_yojson]

    let to_latest = Fn.id
  end

  module V2 = struct
    type t =
      { pending_coinbases : Pending_coinbase.Stable.V2.t; is_new_stack : bool }
    [@@deriving sexp, to_yojson]

    let to_latest ({ pending_coinbases; is_new_stack = _ } : t) : V3.t =
      { pending_coinbases =
          Pending_coinbase.Stable.V2.to_latest pending_coinbases
      }
  end
end]
