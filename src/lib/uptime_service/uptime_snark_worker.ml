(* uptime_snark_worker.ml *)

open Core_kernel
open Async
open Mina_base

open struct
  module Impl = Snark_worker.Impl
end

let extract_terminal_zk_segment ~(m : (module Transaction_snark.S)) ~witness
    ~input ~zkapp_command ~staged_ledger_hash =
  let staged_ledger_hash = Staged_ledger_hash.ledger_hash staged_ledger_hash in
  let%bind.Result final_segment =
    Work_partitioner.Snark_worker_shared.extract_zkapp_segment_works ~m ~input
      ~witness ~zkapp_command
    |> Result.map_error
         ~f:
           Work_partitioner.Snark_worker_shared.Failed_to_generate_inputs
           .error_of_t
    |> Result.map ~f:(function x ->
           Work_partitioner.Snark_worker_shared.Zkapp_command_inputs
           .read_all_proofs_from_disk x
           |> Mina_stdlib.Nonempty_list.find ~f:(function _, _, s ->
                  Ledger_hash.(s.target.second_pass_ledger = staged_ledger_hash) ) )
  in
  match final_segment with
  | Some res ->
      Ok res
  | _ ->
      Error
        ( Error.of_string
        @@ sprintf "Failed to find zkapp segment with target hash %s"
             (Ledger_hash0.to_base58_check staged_ledger_hash) )

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { perform_single :
          ( 'w
          , Sok_message.t * Snark_work_lib.Spec.Single.Stable.Latest.t
          , (Ledger_proof.t * Time.Span.t) Or_error.t )
          F.t
      ; perform_partitioned :
          ( 'w
          , Transaction_witness.Stable.Latest.t
            * Mina_state.Snarked_ledger_state.Stable.Latest.t
            * Zkapp_command.Stable.Latest.t
            * Staged_ledger_hash.t
          , (Ledger_proof.t * Time.Span.t) Or_error.t )
          F.t
      }

    module Worker_state = struct
      (* required by rpc_parallel *)
      type init_arg = Logger.t * Genesis_constants.Constraint_constants.t
      [@@deriving bin_io_unversioned]

      include Impl.Worker_state
    end

    module Connection_state = struct
      (* bin_io required by rpc_parallel *)
      type init_arg = unit [@@deriving bin_io_unversioned]

      type t = unit
    end

    module Functions
        (C : Rpc_parallel.Creator
               with type worker_state := Worker_state.t
                and type connection_state := Connection_state.t) =
    struct
      let perform_single (state : Worker_state.t) (message, single_spec) =
        Impl.perform_single ~message state single_spec

      let perform_partitioned (state : Worker_state.t)
          (witness, statement, zkapp_command, staged_ledger_hash) =
        let zkapp_command =
          Zkapp_command.write_all_proofs_to_disk
            ~signature_kind:state.signature_kind
            ~proof_cache_db:state.proof_cache_db zkapp_command
        in
        match state.proof_level_snark with
        | Full (module S) ->
            let%bind.Deferred.Or_error witness, spec, statement =
              extract_terminal_zk_segment
                ~m:(module S)
                ~witness ~input:statement ~zkapp_command ~staged_ledger_hash
              |> Deferred.return
            in

            Snark_worker.Impl.measure_runtime ~logger:state.logger
              ~spec_json:
                ( lazy
                  ( "zkapp_segment_spec"
                  , Transaction_snark.Zkapp_command_segment.Basic.Stable.Latest
                    .to_yojson spec ) )
              (fun () ->
                let witness =
                  Transaction_witness.Zkapp_command_segment_witness
                  .write_all_proofs_to_disk witness
                    ~proof_cache_db:state.proof_cache_db
                    ~signature_kind:state.signature_kind
                in
                S.of_zkapp_command_segment_exn ~statement ~witness ~spec
                |> Deferred.map ~f:(fun a -> Result.Ok a) )
        | _ ->
            Deferred.Or_error.error_string
              "Unexpected prover mode in uptime snark worker"

      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        { perform_single =
            f
              ( [%bin_type_class:
                  Sok_message.Stable.Latest.t
                  * Snark_work_lib.Spec.Single.Stable.Latest.t]
              , [%bin_type_class:
                  (Ledger_proof.Stable.Latest.t * Time.Span.t) Or_error.t]
              , perform_single )
        ; perform_partitioned =
            f
              ( [%bin_type_class:
                  Transaction_witness.Stable.Latest.t
                  * Mina_state.Snarked_ledger_state.Stable.Latest.t
                  * Zkapp_command.Stable.Latest.t
                  * Staged_ledger_hash.Stable.Latest.t]
              , [%bin_type_class:
                  (Ledger_proof.Stable.Latest.t * Time.Span.t) Or_error.t]
              , perform_partitioned )
        }

      let init_worker_state (logger, constraint_constants) =
        [%log info] "Uptime SNARK worker started" ;
        Worker_state.create ~constraint_constants ~proof_level:Full
          ~signature_kind:Mina_signature_kind.t_DEPRECATED ()

      let init_connection_state ~connection:_ ~worker_state:_ () = Deferred.unit
    end
  end

  include Rpc_parallel.Make (T)
end

type t =
  { connection : Worker.Connection.t; process : Process.t; logger : Logger.t }

let create ~logger ~constraint_constants ~pids : t Deferred.t =
  let on_failure err =
    [%log error] "Uptime service SNARK worker process failed with error $err"
      ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
    Error.raise err
  in
  [%log info] "Starting a new uptime service SNARK worker process" ;
  let%map connection, process =
    Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
      ~on_failure ~shutdown_on:Connection_closed ~connection_state_init_arg:()
      (logger, constraint_constants)
  in
  [%log info]
    "Daemon started process of kind $process_kind with pid \
     $uptime_snark_worker_pid"
    ~metadata:
      [ ("uptime_snark_worker_pid", `Int (Process.pid process |> Pid.to_int))
      ; ( "process_kind"
        , `String
            Child_processes.Termination.(show_process_kind Uptime_snark_worker)
        )
      ] ;
  Child_processes.Termination.register_process pids process
    Child_processes.Termination.Uptime_snark_worker ;
  let pid = Process.pid process in
  [%log info] "Uptime snark worker process has PID %d" (Pid.to_int pid) ;
  Mina_metrics.Process_memory.Uptime_snark_worker.set_pid pid ;
  (* the wait loop in the daemon will terminate the daemon if this SNARK worker
     process dies

     when this code is migrated to `compatible`, please follow the strategy
     used in prover.ml to call Async.exit when the prover terminates
  *)
  don't_wait_for
  @@ Pipe.iter
       (Process.stdout process |> Reader.pipe)
       ~f:(fun stdout ->
         return
         @@ [%log debug] "Uptime SNARK worker stdout: $stdout"
              ~metadata:[ ("stdout", `String stdout) ] ) ;
  don't_wait_for
  @@ Pipe.iter
       (Process.stderr process |> Reader.pipe)
       ~f:(fun stderr ->
         return
         @@ [%log error] "Uptime SNARK worker stderr: $stderr"
              ~metadata:[ ("stderr", `String stderr) ] ) ;
  { connection; process; logger }

let perform_single { connection; _ } ((_message, _single_spec) as arg) =
  Worker.Connection.run connection ~f:Worker.functions.perform_single ~arg

let perform_partitioned { connection; _ } arg =
  Worker.Connection.run connection ~f:Worker.functions.perform_partitioned ~arg
