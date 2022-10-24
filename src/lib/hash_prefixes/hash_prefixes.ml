let length_in_bytes = 20

module T : sig
  type t = private string

  val create : string -> t
end = struct
  type t = string

  let padding_char = '*'

  let create s : t =
    let string_length = String.length s in
    assert (string_length <= length_in_bytes) ;
    let diff = length_in_bytes - string_length in
    let r = s ^ String.init diff (fun _ -> padding_char) in
    assert (String.length r = length_in_bytes) ;
    r
end

include T

let protocol_state = create "MinaProtoState"

let protocol_state_body = create "MinaProtoStateBody"

let account = create "MinaAccount"

let side_loaded_vk = create "MinaSideLoadedVk"

let zkapp_account = create "MinaZkappAccount"

let zkapp_payload = create "MinaZkappPayload"

let zkapp_body = create "MinaZkappBody"

let merkle_tree i = create (Printf.sprintf "MinaMklTree%03d" i)

let coinbase_merkle_tree i = create (Printf.sprintf "MinaCbMklTree%03d" i)

let merge_snark = create "MinaMergeSnark"

let base_snark = create "MinaBaseSnark"

let transition_system_snark = create "MinaTransitionSnark"

let signature_testnet = create "MinaSignature"

let signature_mainnet = create "MinaSignatureMainnet"

let receipt_chain_user_command = create "MinaReceiptUC"

(* leaving this one with "Coda", to preserve the existing hashes *)
let receipt_chain_zkapp = create "CodaReceiptZkapp"

let epoch_seed = create "MinaEpochSeed"

let vrf_message = create "MinaVrfMessage"

let vrf_output = create "MinaVrfOutput"

let vrf_evaluation = create "MinaVrfEvaluation"

let pending_coinbases = create "PendingCoinbases"

let coinbase_stack_data = create "CoinbaseStackData"

(* length is limited, so we drop some characters here *)
let coinbase_stack_state_hash = create "CoinbaseStackStaHash"

let coinbase_stack = create "CoinbaseStack"

let coinbase = create "Coinbase"

let checkpoint_list = create "MinaCheckpoints"

let bowe_gabizon_hash = create "MinaWrapBGHash"

let zkapp_precondition = create "MinaZkappPred"

(*for Zkapp_precondition.Account.t*)
let zkapp_precondition_account = create "MinaZkappPredAcct"

let zkapp_precondition_protocol_state = create "MinaZkappPredPS"

(*for Account_update.Account_precondition.t*)
let account_update_account_precondition = create "MinaAcctUpdAcctPred"

let account_update = create "MinaAcctUpdate"

let account_update_cons = create "MinaAcctUpdateCons"

let account_update_node = create "MinaAcctUpdateNode"

let account_update_stack_frame = create "MinaAcctUpdStckFrm"

let account_update_stack_frame_cons = create "MinaActUpStckFrmCons"

let zkapp_uri = create "MinaZkappUri"

let zkapp_event = create "MinaZkappEvent"

let zkapp_events = create "MinaZkappEvents"

let zkapp_sequence_events = create "MinaZkappSeqEvents"

let zkapp_memo = create "MinaZkappMemo"

let zkapp_test = create "MinaZkappTest"

let derive_token_id = create "MinaDeriveTokenId"
