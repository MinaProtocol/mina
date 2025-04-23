open Core_kernel
open Async_kernel

let diff_s a b = Time_ns.(Span.to_string_hum (diff a b))

let time_genesis_creation () =
  let commit_id = "<skipped for unit test>" in
  let logger = Logger.create () in
  Logger.Consumer_registry.register ~id:Logger.Logger_id.mina ~commit_id
    ~processor:Internal_tracing.For_logger.processor
    ~transport:
      (Logger_file_system.dumb_logrotate ~directory:"."
         ~log_filename:"internal-tracing.log"
         ~max_size:(1024 * 1024 * 10)
         ~num_rotate:50 )
    () ;
  let%bind () = Internal_tracing.toggle `Enabled ~commit_id ~logger in
  let start = Time_ns.now () in
  let%bind worker_state =
    Prover.Worker_state.create
      { Prover.Worker_state.conf_dir = "<skipped for unit test>"
      ; enable_internal_tracing = false
      ; internal_trace_filename = None
      ; logger
      ; proof_level = Full
      ; signature_kind = Mina_signature_kind.Testnet
      ; constraint_constants =
          Genesis_constants.For_unit_tests.Constraint_constants.t
      ; commit_id
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
