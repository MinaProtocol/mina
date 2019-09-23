(* version_bytes.ml -- version bytes for Base58Check encodings *)

type t = char

(* each of the following values should be distinct *)

let user_command : t = '\x17'

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

let lite_precomputed : t = '\xBC'

let receipt_chain_hash : t = '\x9D'

let transaction_hash : t = '\x9E'

let fee_transfer_single : t = '\x9F'

let secret_box_byteswr : t = '\x02'

let ledger_hash : t = '\x63'
