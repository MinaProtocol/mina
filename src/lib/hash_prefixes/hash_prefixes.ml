let length_in_bytes = 20

let length_in_triples = ((8 * length_in_bytes) + 2) / 3

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

let merkle_tree i = create (Printf.sprintf "CodaMklTree%03d" i)

let proof_of_work = create "CodaPoW"

let merge_snark = create "CodaMergeSnark"

let base_snark = create "CodaBaseSnark"

let transition_system_snark = create "CodaTransitionSnark"

let signature = create "CodaSignature"

let receipt_chain = create "CodaReceiptChain"

let epoch_seed = create "CodaEpochSeed"

let vrf_message = create "CodaVrfMessage"

let vrf_output = create "CodaVrfOutput"

let checkpoint_list = create "CodaCheckpoints"
