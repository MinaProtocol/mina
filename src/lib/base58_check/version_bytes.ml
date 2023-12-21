(* version_bytes.ml -- version bytes for Base58Check encodings *)

type t = char

(** Base58Check version bytes for individual types
    Each of the following values should be distinct
*)

let coinbase : t = '\x01'

let secret_box_byteswr : t = '\x02'

let fee_transfer_single : t = '\x03'

let frontier_hash : t = '\x04'

let ledger_hash : t = '\x05'

let lite_precomputed : t = '\x06'

let proof : t = '\x0A'

let random_oracle_base : t = '\x0B'

let receipt_chain_hash : t = '\x0C'

let epoch_seed : t = '\x0D'

let staged_ledger_hash_aux_hash : t = '\x0E'

let staged_ledger_hash_pending_coinbase_aux : t = '\x0F'

let state_hash : t = '\x10'

let state_body_hash : t = '\x11'

(* don't use \x12, which was for pre-Berkeley hard fork transaction hashes *)

(* used only to deserialize transaction ids, pre-Berkeley hard fork *)
let signed_command_v1 : t = '\x13'

let user_command_memo : t = '\x14'

let vrf_truncated_output : t = '\x15'

let web_pipe : t = '\x16'

let coinbase_stack_data : t = '\x17'

let coinbase_stack_hash : t = '\x18'

let pending_coinbase_hash_builder : t = '\x19'

let zkapp_command : t = '\x1A'

let verification_key : t = '\x1B'

let token_id_key : t = '\x1C'

let transaction_hash : t = '\x1D'

(** used for testing only *)

let ledger_test_hash : t = '\x30'

(** The following version bytes are non-sequential; existing
    user key infrastructure depends on them. don't change them!
*)

let private_key : t = '\x5A'

let non_zero_curve_point_compressed : t = '\xCB'

let signature : t = '\x9A'
