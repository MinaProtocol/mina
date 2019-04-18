open Core_kernel

module Stable = struct
  module V1 = struct
    module T = struct
      type ('a, 'h) t = {data: 'a; hash: 'h}
      [@@deriving sexp, bin_io, compare, to_yojson, version]
    end

    include T
  end

  module Latest = V1
end

type ('a, 'h) t = ('a, 'h) Stable.Latest.t = {data: 'a; hash: 'h}
[@@deriving sexp, compare, to_yojson]

let data {data; _} = data

let hash {hash; _} = hash

let map t ~f = {t with data= f t.data}

let of_data data ~hash_data = {data; hash= hash_data data}
