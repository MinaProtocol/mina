open Core_kernel

let length_in_bytes = 20

let length_in_triples = Util.bit_length_to_triple_length (8 * length_in_bytes)

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
    let r = s ^ String.init diff ~f:(fun _ -> padding_char) in
    assert (String.length r = length_in_bytes) ;
    r
end

let salt s =
  Snark_params.Tick.Pedersen.(State.salt params (T.create s :> string))

let protocol_state = salt "CodaProtoState"

let account = salt "CodaAccount"

let merkle_tree =
  Array.init Snark_params.ledger_depth ~f:(fun i ->
      salt (sprintf "CodaMklTree%03d" i) )

let proof_of_work = salt "CodaPoW"

let merge_snark = salt "CodaMergeSnark"

let base_snark = salt "CodaBaseSnark"

let transition_system_snark = salt "CodaTransitionSnark"

let signature = salt "CodaSignature"

let receipt_chain = salt "CodaReceiptChain"

let epoch_seed = salt "CodaEpochSeed"

let vrf_message = salt "CodaVrfMessage"

let vrf_output = salt "CodaVrfOutput"
