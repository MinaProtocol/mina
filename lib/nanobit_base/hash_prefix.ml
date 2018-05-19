open Core_kernel

let length = 20

module T : sig
  type t = private string
  val create : string -> t
end = struct
  type t = string

  let padding_char = '*'

  let create s : t =
    let string_length = String.length s in
    assert (string_length <= length);
    let diff = length - string_length in
    s ^ String.init diff ~f:(fun _ -> padding_char)
end

let salt s =
  let open Snark_params.Tick.Pedersen in
  State.salt params (T.create s :> string)

let blockchain_state = salt "CodaBCState"

let account = salt "CodaAccount"

let merkle_tree =
  Array.init Snark_params.ledger_depth ~f:(fun i ->
    salt (sprintf "CodaMklTree%03d" i))

let proof_of_work = salt "CodaPoW"

let merge_snark = salt "CodaMergeSnark"

let base_snark = salt "CodaBaseSnark"

let transition_system_snark = salt "CodaTransitionSnark"

let signature = salt "CodaSignature"
