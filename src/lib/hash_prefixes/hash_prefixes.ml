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

let protocol_state = create "CodaProtoState"

let protocol_state_body = create "CodaProtoStateBody"

let account = create "CodaAccount"

let side_loaded_vk = create "CodaSideLoadedVk"

let zkapp_account = create "CodaZkappAccount"

let zkapp_payload = create "CodaZkappPayload"

let zkapp_body = create "CodaZkappBody"

let merkle_tree i = create (Printf.sprintf "CodaMklTree%03d" i)

let coinbase_merkle_tree i = create (Printf.sprintf "CodaCbMklTree%03d" i)

let merge_snark = create "CodaMergeSnark"

let base_snark = create "CodaBaseSnark"

let transition_system_snark = create "CodaTransitionSnark"

let signature_testnet = create "CodaSignature"

let signature_mainnet = create "MinaSignatureMainnet"

let receipt_chain_user_command = create "CodaReceiptUC"

let receipt_chain_zkapp = create "CodaReceiptZkapp"

let epoch_seed = create "CodaEpochSeed"

let vrf_message = create "CodaVrfMessage"

let vrf_output = create "CodaVrfOutput"

let vrf_evaluation = create "MinaVrfEvaluation"

let pending_coinbases = create "PendingCoinbases"

let coinbase_stack_data = create "CoinbaseStackData"

(* length is limited, so we drop some characters here *)
let coinbase_stack_state_hash = create "CoinbaseStackStaHash"

let coinbase_stack = create "CoinbaseStack"

let coinbase = create "Coinbase"

let checkpoint_list = create "CodaCheckpoints"

let bowe_gabizon_hash = create "CodaTockBGHash"

let zkapp_precondition = create "CodaZkappPred"

(*for Zkapp_precondition.Account.t*)
let zkapp_precondition_account = create "CodaZkappPredAcct"

let zkapp_precondition_protocol_state = create "CodaZkappPredPS"

(*for Party.Account_precondition.t*)
let party_account_precondition = create "MinaPartyAccountPred"

let party = create "MinaParty"

let party_cons = create "MinaPartyCons"

let party_node = create "MinaPartyNode"

let party_stack_frame = create "MinaPartyStckFrm"

let party_stack_frame_cons = create "MinaPartyStckFrmCons"

let party_with_protocol_state_predicate = create "MinaPartyStatePred"

let zkapp_uri = create "MinaZkappUri"

let zkapp_event = create "MinaZkappEvent"

let zkapp_events = create "MinaZkappEvents"

let zkapp_sequence_events = create "MinaZkappSeqEvents"

let zkapp_memo = create "MinaZkappMemo"

let zkapp_test = create "MinaZkappTest"

let derive_token_id = create "MinaDeriveTokenId"
