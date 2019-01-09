[%%import
"../../config.mlh"]

open Core
open Async
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

let blocks_till_finality =
  env "BLOCKS_TILL_FINALITY" ~default:1024 ~f:(fun str ->
      try Some (Int.of_string str) with _ -> None )

[%%if
defined consensus_mechanism]

[%%if
consensus_mechanism = "proof_of_signature"]

let blocks_till_finality = 1

include Proof_of_signature.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Proof = Coda_base.Proof
  module Time = Coda_base.Block_time

  let proposal_interval =
    env "PROPOSAL_INTERVAL"
      ~default:(Time.Span.of_ms @@ Int64.of_int 5000)
      ~f:(fun str ->
        try Some (Time.Span.of_ms @@ Int64.of_string str) with _ -> None )
end)

[%%elif
consensus_mechanism = "proof_of_stake"]

include Proof_of_stake.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Proof = Coda_base.Proof
  module Time = Coda_base.Block_time

  module Constants = struct
    (* TODO: change these variables into variables for config file. See #1176  *)
    (* TODO: choose reasonable values *)
    let genesis_state_timestamp =
      let default = Coda_base.Genesis_state_timestamp.value |> Time.of_time in
      env "GENESIS_STATE_TIMESTAMP" ~default ~f:(fun str ->
          try Some (Time.of_time @@ Core.Time.of_string str) with _ -> None )

    let coinbase =
      env "COINBASE" ~default:(Currency.Amount.of_int 20) ~f:(fun str ->
          try Some (Currency.Amount.of_int @@ Int.of_string str) with _ -> None
      )

    let blocks_till_finality = blocks_till_finality

    let slot_length =
      env "SLOT_INTERVAL"
        ~default:(Time.Span.of_ms (Int64.of_int 5000))
        ~f:(fun str ->
          try Some (Time.Span.of_ms @@ Int64.of_string str) with _ -> None )

    let unforkable_transition_count =
      env "UNFORKABLE_TRANSITION_COUNT" ~default:12 ~f:(fun str ->
          try Some (Int.of_string str) with _ -> None )

    let probable_slots_per_transition_count =
      env "PROBABLE_SLOTS_PER_TRANSITION_COUNT" ~default:8 ~f:(fun str ->
          try Some (Int.of_string str) with _ -> None )

    let network_delay =
      env "NETWORK_DELAY" ~default:4 ~f:(fun str ->
          try Some (Int.of_string str) with _ -> None )
  end
end)

[%%endif]

[%%else]

[%%error
"\"consensus_mechanism\" not set in config.mlh"]

[%%endif]
