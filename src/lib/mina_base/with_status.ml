open Core_kernel

module Legacy = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type 'a t = { data : 'a; status : Transaction_status.Legacy.Stable.V1.t }
      [@@deriving sexp, yojson, equal, compare, fields]
    end
  end]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = { data : 'a; status : Transaction_status.Stable.V1.t }
    [@@deriving sexp, yojson, equal, compare, fields]
  end
end]

let to_legacy t =
  { Legacy.data = t.data; status = Transaction_status.to_legacy t.status }

let map ~f { data; status } = { data = f data; status }

let map_opt ~f { data; status } =
  Option.map (f data) ~f:(fun data -> { data; status })

let map_result ~f { data; status } =
  Result.map (f data) ~f:(fun data -> { data; status })
