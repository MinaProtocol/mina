(* version_bytes.ml -- version bytes for Base58Check encodings *)

type t = char

(* each of the following values should be distinct *)

let graphql : t = '\x17'

let web_pipe : t = '\x41'

let data_hash : t = '\x37'

let proof : t = '\x70'

let signature : t = '\x9A'

let non_zero_curve_point : t = '\xCD'

let non_zero_curve_point_compressed : t = '\xCA'

let random_oracle_base : t = '\x03'

let private_key : t = '\x5A'

let staged_ledger_hash_aux_hash : t = '\x0B'

let staged_ledger_hash_pending_coinbase_aux : t = '\x81'

let user_command_memo : t = '\xA2'
