open Core_kernel
open Async_kernel

let diff_s a b = Time_ns.(Span.to_string_hum (diff a b))

let time_genesis_creation () =
  let start = Time_ns.now () in
  let%bind worker_state =
    Prover.Worker_state.create
      { Prover.Worker_state.conf_dir = "<skipped for unit test>"
      ; enable_internal_tracing = false
      ; internal_trace_filename = None
      ; logger = Logger.create ()
      ; proof_level = Full
      ; constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
      ; commit_id = "<skipped for unit test>"
      }
  in
  let worker_state_initialized = Time_ns.now () in
  match%map
    Prover.create_genesis_block_locally worker_state
      (Genesis_proof.to_inputs @@ Lazy.force Precomputed_values.for_unit_tests)
  with
  | Ok _ ->
      printf "%s,%s\n"
        (diff_s worker_state_initialized start)
        (diff_s (Time_ns.now ()) worker_state_initialized)
  | Error e ->
      Base.Error.raise e
