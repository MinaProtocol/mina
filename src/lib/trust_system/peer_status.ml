open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {trust: float; banned: Banned_status.Stable.V1.t}
    [@@deriving yojson]

    let to_latest = Fn.id
  end
end]
