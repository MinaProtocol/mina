type t = {public_key: Public_key.t; private_key: Private_key.t}

let of_private_key_exn private_key =
  let public_key = Public_key.of_private_key_exn private_key in
  {public_key; private_key}

let create () = of_private_key_exn (Private_key.create ())
