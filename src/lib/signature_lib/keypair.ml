open Core_kernel

module T = struct
  type t = {public_key: Public_key.t; private_key: Private_key.t sexp_opaque}
  [@@deriving sexp]

  let compare {public_key= pk1; private_key= _}
      {public_key= pk2; private_key= _} =
    Public_key.compare pk1 pk2
end

include T
include Comparable.Make (T)

let of_private_key_exn private_key =
  let public_key = Public_key.of_private_key_exn private_key in
  {public_key; private_key}

let create () = of_private_key_exn (Private_key.create ())
