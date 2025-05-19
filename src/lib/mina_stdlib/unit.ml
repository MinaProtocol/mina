[%%versioned
module Stable = struct
  module V1 = struct
    type t = unit [@@deriving sexp]

    let to_yojson () : Yojson.Safe.t = `Null

    let of_yojson = function
      | `Null ->
          Ok ()
      | _ ->
          Error "Mina_stdlib.Unit: Could not parse"

    let to_latest = Fn.id
  end
end]
