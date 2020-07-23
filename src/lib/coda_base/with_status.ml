open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type 'a t = {data: 'a; status: User_command_status.Stable.V1.t}
    [@@deriving sexp, yojson, eq, compare]
  end
end]

type 'a t = 'a Stable.Latest.t = {data: 'a; status: User_command_status.t}
[@@deriving sexp, yojson, eq, compare]

let map ~f {data; status} = {data= f data; status}

let map_opt ~f {data; status} =
  Option.map (f data) ~f:(fun data -> {data; status})

let map_result ~f {data; status} =
  Result.map (f data) ~f:(fun data -> {data; status})
