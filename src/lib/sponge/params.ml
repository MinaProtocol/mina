open Core_kernel

type 'a t = {mds: 'a array array; round_constants: 'a array array}
[@@deriving bin_io]

let map {mds; round_constants} ~f =
  let f = Array.map ~f:(Array.map ~f) in
  {mds= f mds; round_constants= f round_constants}
