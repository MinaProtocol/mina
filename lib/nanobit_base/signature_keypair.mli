type t =
  { public_key  : Public_key.t
  ; private_key : Private_key.t
  }

val create : unit -> t
