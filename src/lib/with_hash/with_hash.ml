open Core_kernel

type ('a, 'h) t = {data: 'a; hash: 'h}
[@@deriving sexp, bin_io, compare, to_yojson]

let data {data; _} = data

let hash {hash; _} = hash

let map t ~f = {t with data= f t.data}

let of_data data ~hash_data = {data; hash= hash_data data}
