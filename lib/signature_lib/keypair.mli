type t = {public_key: Public_key.t; private_key: Private_key.t}

val of_private_key_exn : Private_key.t -> t

val create : unit -> t
