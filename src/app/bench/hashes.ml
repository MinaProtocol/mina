open Core
open Coda_base

let%bench "merging empty hashes" =
  Merkle_hash.(merge ~height:0 empty_hash empty_hash) |> ignore

module Pos = Consensus.Proof_of_stake.Make (struct
  module Genesis_ledger = Genesis_ledger
  module Proof = Coda_base.Proof
  module Ledger_builder_diff = Int
  module Time = Coda_base.Block_time

  (* These parameters shouldn't matter for the benches below *)

  let genesis_state_timestamp =
    Core.Time.of_date_ofday
      ~zone:(Core.Time.Zone.of_utc_offset ~hours:(-7))
      (Core.Date.create_exn ~y:2018 ~m:Month.Sep ~d:1)
      (Core.Time.Ofday.create ~hr:10 ())
    |> Time.of_time

  let coinbase = Currency.Amount.of_int 20

  let slot_interval = Time.Span.of_ms (Int64.of_int 5000)

  let unforkable_transition_count = 12

  let probable_slots_per_transition_count = 8

  let expected_network_delay = Time.Span.of_ms (Int64.of_int 1000)

  let approximate_network_diameter = 3
end)

let%bench_fun "hashing the postake genesis protocol state" =
  let pstate = Pos.genesis_protocol_state in
  fun () -> Pos.Protocol_state.hash pstate |> ignore
