open Core_kernel

[%%versioned
module Stable = struct
  module V2 = struct
    type 'a t = 'a Mina_wire_types.Mina_base.With_status.V2.t =
      { data : 'a; status : Transaction_status.Stable.V2.t }
    [@@deriving sexp, yojson, equal, compare, fields]

    let to_latest data_latest (t : _ t) =
      { data = data_latest t.data; status = t.status }
  end
end]

let map ~f { data; status } = { data = f data; status }

let map_opt ~f { data; status } =
  Option.map (f data) ~f:(fun data -> { data; status })

let map_result ~f { data; status } =
  Result.map (f data) ~f:(fun data -> { data; status })
