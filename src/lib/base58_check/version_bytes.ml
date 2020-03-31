(* version_bytes.ml -- version bytes for Base58Check encodings *)

type t = char

(* each of the following values should be distinct *)

let coinbase : t = '\x04'

let epoch_seed : t = '\x25'

let fee_transfer_single : t = '\x9F'

let frontier_hash : t = '\xAC'

let ledger_hash : t = '\x63'

let lite_precomputed : t = '\xBC'

let non_zero_curve_point : t = '\xCE'

let non_zero_curve_point_compressed : t = '\xCB'

let private_key : t = '\x5A'

let proof : t = '\x70'

let random_oracle_base : t = '\x03'

let receipt_chain_hash : t = '\x9D'

let secret_box_byteswr : t = '\x02'

let signature : t = '\x9A'

let staged_ledger_hash_aux_hash : t = '\x0B'

let staged_ledger_hash_pending_coinbase_aux : t = '\x81'

let state_hash : t = '\x20'

let transaction_hash : t = '\x9E'

let user_command : t = '\x17'

let user_command_memo : t = '\xA2'

let vrf_truncated_output : t = '\xA3'

let web_pipe : t = '\x41'
