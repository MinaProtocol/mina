(* The unprocessed transition cache is a cache of transitions which have been
 * ingested from the network but have not yet been processed into the transition
 * frontier. This is used in order to drop duplicate transitions which are still
 * being handled by various threads in the transition frontier controller. *)

open Core_kernel
open Mina_base
open Network_peer

module Name = struct
  let t = __MODULE__
end

module Transmuter = struct
  module Source = struct
    type t = Mina_block.initial_valid_block Envelope.Incoming.t
  end

  module Target = struct
    include State_hash

    let to_string = to_base58_check
  end

  let transmute enveloped_transition =
    let transition, _ = Envelope.Incoming.data enveloped_transition in
    State_hash.With_state_hashes.state_hash transition
end

module Registry = struct
  type element = State_hash.t

  let element_added _ =
    Mina_metrics.(
      Gauge.inc_one Transition_frontier_controller.transitions_being_processed)

  let element_removed outcome state_hash =
    Block_outcome_log.record (fun () -> Cache_removed { state_hash; outcome }) ;
    Mina_metrics.(
      Gauge.dec_one Transition_frontier_controller.transitions_being_processed)
end

include Cache_lib.Transmuter_cache.Make (Transmuter) (Registry) (Name)

let%test_module "Recording block outcomes" =
  ( module struct
    let precomputed_values = Lazy.force Precomputed_values.for_unit_tests

    (* The genesis block, validated as far as a block entering the cache is. *)
    let initial_valid_block =
      Mina_block.genesis ~precomputed_values
      |> Mina_block.Validation.reset_frontier_dependencies_validation
      |> Mina_block.Validation.reset_staged_ledger_diff_validation
      |> Envelope.Incoming.local

    let state_hash =
      State_hash.With_state_hashes.state_hash
        (Mina_block.Validation.block_with_hash
           (Envelope.Incoming.data initial_valid_block) )

    let outcome_of ~finish =
      let cache = create ~logger:(Logger.null ()) ~cache_exceptions:false in
      let (), events =
        Block_outcome_log.For_tests.recording (fun () ->
            finish (register_exn cache initial_valid_block) ;
            Gc.full_major () )
      in
      events

    let%test_unit "A consumed entry is recorded" =
      [%test_eq: Block_outcome_log.event list]
        (outcome_of ~finish:(fun cached ->
             ignore (Cache_lib.Cached.invalidate_with_success cached : _) ) )
        [ Cache_removed { state_hash; outcome = `Consumed } ]

    let%test_unit "An invalidated entry is recorded" =
      [%test_eq: Block_outcome_log.event list]
        (outcome_of ~finish:(fun cached ->
             ignore (Cache_lib.Cached.invalidate_with_failure cached : _) ) )
        [ Cache_removed { state_hash; outcome = `Failure } ]

    let%test_unit "A dropped entry is recorded when collected" =
      [%test_eq: Block_outcome_log.event list]
        (outcome_of ~finish:(fun (_ : _ Cache_lib.Cached.t) -> ()))
        [ Cache_removed { state_hash; outcome = `Unconsumed } ]
  end )
