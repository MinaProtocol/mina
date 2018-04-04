type t =
  { public_key  : Public_key.t
  ; private_key : Private_key.t
  }

let create () =
  assert Insecure.key_generation;
  let private_key = Private_key.create () in
  let public_key = Public_key.of_private_key private_key in
  { public_key; private_key }
