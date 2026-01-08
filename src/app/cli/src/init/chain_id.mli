type inputs =
  { genesis_state_hash : Data_hash_lib.State_hash.t
  ; genesis_constants : Genesis_constants.t
  ; constraint_system_digests : (string * Md5_lib.t) list
  ; protocol_transaction_version : int
  ; protocol_network_version : int
  }

type t

val make : inputs -> t

val to_string : t -> string
