[%%import
"../../config.mlh"]

open Core
open Async
module Proof_of_stake0 = Proof_of_stake
module Proof_of_signature0 = Proof_of_signature
include Intf

let exit1 ?msg =
  match msg with
  | None -> Core.exit 1
  | Some msg ->
      Core.Printf.eprintf "%s\n" msg ;
      Core.exit 1

let env name ~f ~default =
  let name = Printf.sprintf "CODA_%s" name in
  Unix.getenv name
  |> Option.map ~f:(fun x ->
         match f @@ String.uppercase x with
         | Some v -> v
         | None ->
             exit1
               ~msg:
                 (Printf.sprintf
                    "Inside env var %s, there was a value I don't understand \
                     \"%s\""
                    name x) )
  |> Option.value ~default

module Constants0 = struct
  let k =
    env "K" ~default:12 ~f:(fun str ->
        try Some (Int.of_string str) with _ -> None )

  let coinbase =
    env "COINBASE" ~default:(Currency.Amount.of_int 20) ~f:(fun str ->
        try Some (Currency.Amount.of_int @@ Int.of_string str) with _ -> None
    )

  let block_duration_ms =
    env "BLOCK_DURATION" ~default:(Int64.of_int 5000) ~f:(fun str ->
        try Some (Int64.of_string str) with _ -> None )
end

[%%if
defined consensus_mechanism]

[%%if
consensus_mechanism = "proof_of_signature"]

let blocks_till_finality = 1

let name = "proof_of_signature"

include Proof_of_signature0.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Proof = Coda_base.Proof
  module Time = Coda_base.Block_time
  module Constants = Constants0
end)

[%%elif
consensus_mechanism = "proof_of_stake"]

let name = "proof_of_stake"

include Proof_of_stake0.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Proof = Coda_base.Proof
  module Time = Coda_base.Block_time

  module Constants = struct
    include Constants0

    (* TODO: change these variables into variables for config file. See #1176  *)
    (* TODO: choose reasonable values *)
    let genesis_state_timestamp =
      let default = Coda_base.Genesis_state_timestamp.value |> Time.of_time in
      env "GENESIS_STATE_TIMESTAMP" ~default ~f:(fun str ->
          try Some (Time.of_time @@ Core.Time.of_string str) with _ -> None )

    let c =
      env "C" ~default:8 ~f:(fun str ->
          try Some (Int.of_string str) with _ -> None )

    let delta =
      env "DELTA" ~default:4 ~f:(fun str ->
          try Some (Int.of_string str) with _ -> None )
  end
end)

[%%endif]

[%%else]

[%%error
"\"consensus_mechanism\" not set in config.mlh"]

[%%endif]
