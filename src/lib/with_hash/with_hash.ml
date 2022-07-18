open Core_kernel

type ('a, 'h) t = { data : 'a; hash : 'h }
[@@deriving annot, sexp, equal, compare, hash, yojson]

let data { data; _ } = data

let hash { hash; _ } = hash

let map t ~f = { t with data = f t.data }

let map_hash t ~f = { t with hash = f t.hash }

let of_data data ~hash_data = { data; hash = hash_data data }
