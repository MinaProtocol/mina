(* prod.ml *)

open Core_kernel
open Async
open Mina_base
open Mina_state
open Blockchain_snark

type invalid = Common.invalid [@@deriving bin_io_unversioned, to_yojson]

let invalid_to_error = Common.invalid_to_error

type ledger_proof = Ledger_proof.Prod.t

module Worker_state = struct
  module type S = sig
    val verify_blockchain_snarks :
      (Protocol_state.Value.t * Proof.t) list -> unit Or_error.t Deferred.t

    val verify_commands :
         Mina_base.User_command.Verifiable.t With_status.t list
      -> [ `Valid of Mina_base.User_command.Valid.t
         | `Valid_assuming of
           ( Pickles.Side_loaded.Verification_key.t
           * Mina_base.Zkapp_statement.t
           * Pickles.Side_loaded.Proof.t )
           list
         | invalid ]
         list
         Deferred.t

    val verify_transaction_snarks :
      (Transaction_snark.t * Sok_message.t) list -> unit Or_error.t Deferred.t

    val get_blockchain_verification_key : unit -> Pickles.Verification_key.t

    val toggle_internal_tracing : bool -> unit

    val set_itn_logger_data : daemon_port:int -> unit
  end

  (* bin_io required by rpc_parallel *)
  type init_arg =
    { conf_dir : string option
    ; enable_internal_tracing : bool
    ; internal_trace_filename : string option
    ; logger : Logger.Stable.Latest.t
    ; proof_level : Genesis_constants.Proof_level.t
    ; constraint_constants : Genesis_constants.Constraint_constants.t
    }
  [@@deriving bin_io_unversioned]

  type t = (module S)

  let create { logger; proof_level; constraint_constants; _ } : t Deferred.t =
    Memory_stats.log_memory_stats logger ~process:"verifier" ;
    match proof_level with
    | Full ->
        Pickles.Side_loaded.srs_precomputation () ;
        Deferred.return
          (let module M = struct
             module T = Transaction_snark.Make (struct
               let constraint_constants = constraint_constants

               let proof_level = proof_level
             end)

             module B = Blockchain_snark_state.Make (struct
               let tag = T.tag

               let constraint_constants = constraint_constants

               let proof_level = proof_level
             end)

             let verify_commands
                 (cs : User_command.Verifiable.t With_status.t list) :
                 _ list Deferred.t =
               let cs = List.map cs ~f:Common.check in
               let to_verify =
                 List.concat_map cs ~f:(function
                   | `Valid _ ->
                       []
                   | `Valid_assuming (_, xs) ->
                       xs
                   | `Invalid_keys _
                   | `Invalid_signature _
                   | `Invalid_proof _
                   | `Missing_verification_key _
                   | `Unexpected_verification_key _
                   | `Mismatched_authorization_kind _ ->
                       [] )
               in
               let%map all_verified =
                 Pickles.Side_loaded.verify ~typ:Zkapp_statement.typ to_verify
               in
               List.map cs ~f:(function
                 | `Valid c ->
                     `Valid c
                 | `Valid_assuming (c, xs) ->
                     if Or_error.is_ok all_verified then `Valid c
                     else `Valid_assuming xs
                 | `Invalid_keys keys ->
                     `Invalid_keys keys
                 | `Invalid_signature keys ->
                     `Invalid_signature keys
                 | `Invalid_proof err ->
                     `Invalid_proof err
                 | `Missing_verification_key keys ->
                     `Missing_verification_key keys
                 | `Unexpected_verification_key keys ->
                     `Unexpected_verification_key keys
                 | `Mismatched_authorization_kind keys ->
                     `Mismatched_authorization_kind keys )

             let verify_commands cs =
               Internal_tracing.Context_logger.with_logger (Some logger)
               @@ fun () ->
               Internal_tracing.Context_call.with_call_id
               @@ fun () ->
               [%log internal] "Verifier_verify_commands" ;
               let%map result = verify_commands cs in
               [%log internal] "Verifier_verify_commands_done" ;
               result

             let verify_blockchain_snarks = B.Proof.verify

             let verify_blockchain_snarks bs =
               Internal_tracing.Context_logger.with_logger (Some logger)
               @@ fun () ->
               Internal_tracing.Context_call.with_call_id
               @@ fun () ->
               [%log internal] "Verifier_verify_blockchain_snarks" ;
               let%map result = verify_blockchain_snarks bs in
               [%log internal] "Verifier_verify_blockchain_snarks_done" ;
               result

             let verify_transaction_snarks ts =
               match Or_error.try_with (fun () -> T.verify ts) with
               | Ok result ->
                   result
               | Error e ->
                   [%log error]
                     ~metadata:[ ("error", Error_json.error_to_yojson e) ]
                     "Verifier threw an exception while verifying transaction \
                      snark" ;
                   failwith "Verifier crashed"

             let verify_transaction_snarks ts =
               Internal_tracing.Context_logger.with_logger (Some logger)
               @@ fun () ->
               Internal_tracing.Context_call.with_call_id
               @@ fun () ->
               [%log internal] "Verifier_verify_transaction_snarks" ;
               let%map result = verify_transaction_snarks ts in
               [%log internal] "Verifier_verify_transaction_snarks_done" ;
               result

             let get_blockchain_verification_key () =
               Lazy.force B.Proof.verification_key

             let toggle_internal_tracing enabled =
               don't_wait_for
               @@ Internal_tracing.toggle ~logger
                    (if enabled then `Enabled else `Disabled)

             let set_itn_logger_data ~daemon_port =
               Itn_logger.set_data ~process_kind:"verifier" ~daemon_port
           end in
          (module M : S) )
    | Check | None ->
        Deferred.return
        @@ ( module struct
             let verify_commands cs =
               List.map cs ~f:(fun c ->
                   match Common.check c with
                   | `Valid c ->
                       `Valid c
                   | `Valid_assuming (c, _) ->
                       `Valid c
                   | `Invalid_keys keys ->
                       `Invalid_keys keys
                   | `Invalid_signature keys ->
                       `Invalid_signature keys
                   | `Invalid_proof err ->
                       `Invalid_proof err
                   | `Missing_verification_key keys ->
                       `Missing_verification_key keys
                   | `Unexpected_verification_key keys ->
                       `Unexpected_verification_key keys
                   | `Mismatched_authorization_kind keys ->
                       `Mismatched_authorization_kind keys )
               |> Deferred.return

             let verify_blockchain_snarks _ = Deferred.return (Ok ())

             let verify_transaction_snarks _ = Deferred.return (Ok ())

             let vk =
               lazy
                 (let module T = Transaction_snark.Make (struct
                    let constraint_constants = constraint_constants

                    let proof_level = proof_level
                  end) in
                 let module B = Blockchain_snark_state.Make (struct
                   let tag = T.tag

                   let constraint_constants = constraint_constants

                   let proof_level = proof_level
                 end) in
                 Lazy.force B.Proof.verification_key )

             let get_blockchain_verification_key () = Lazy.force vk

             let toggle_internal_tracing _ = ()

             let set_itn_logger_data ~daemon_port:_ = ()
           end : S )

  let get = Fn.id
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { verify_blockchains : ('w, Blockchain.t list, unit Or_error.t) F.t
      ; verify_transaction_snarks :
          ('w, (Transaction_snark.t * Sok_message.t) list, unit Or_error.t) F.t
      ; verify_commands :
          ( 'w
          , User_command.Verifiable.t With_status.t list
          , [ `Valid of User_command.Valid.t
            | `Valid_assuming of
              ( Pickles.Side_loaded.Verification_key.t
              * Mina_base.Zkapp_statement.t
              * Pickles.Side_loaded.Proof.t )
              list
            | invalid ]
            list )
          F.t
      ; get_blockchain_verification_key :
          ('w, unit, Pickles.Verification_key.t) F.t
      ; toggle_internal_tracing : ('w, bool, unit) F.t
      ; set_itn_logger_data : ('w, int, unit) F.t
      }

    module Worker_state = Worker_state

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
      let verify_blockchains (w : Worker_state.t) (chains : Blockchain.t list) =
        let (module M) = Worker_state.get w in
        M.verify_blockchain_snarks
          (List.map chains ~f:(fun snark ->
               ( Blockchain_snark.Blockchain.state snark
               , Blockchain_snark.Blockchain.proof snark ) ) )

      let verify_transaction_snarks (w : Worker_state.t) ts =
        let (module M) = Worker_state.get w in
        M.verify_transaction_snarks ts

      let verify_commands (w : Worker_state.t) ts =
        let (module M) = Worker_state.get w in
        M.verify_commands ts

      let get_blockchain_verification_key (w : Worker_state.t) () =
        let (module M) = Worker_state.get w in
        Deferred.return (M.get_blockchain_verification_key ())

      let toggle_internal_tracing (w : Worker_state.t) enabled =
        let (module M) = Worker_state.get w in
        M.toggle_internal_tracing enabled ;
        Deferred.unit

      let set_itn_logger_data (w : Worker_state.t) daemon_port =
        let (module M) = Worker_state.get w in
        M.set_itn_logger_data ~daemon_port ;
        Deferred.unit

      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        { verify_blockchains =
            f
              ( [%bin_type_class: Blockchain.Stable.Latest.t list]
              , [%bin_type_class: unit Or_error.t]
              , verify_blockchains )
        ; verify_transaction_snarks =
            f
              ( [%bin_type_class:
                  ( Transaction_snark.Stable.Latest.t
                  * Sok_message.Stable.Latest.t )
                  list]
              , [%bin_type_class: unit Or_error.t]
              , verify_transaction_snarks )
        ; verify_commands =
            f
              ( [%bin_type_class:
                  User_command.Verifiable.Stable.Latest.t
                  With_status.Stable.Latest.t
                  list]
              , [%bin_type_class:
                  [ `Valid of User_command.Valid.Stable.Latest.t
                  | `Valid_assuming of
                    ( Pickles.Side_loaded.Verification_key.Stable.Latest.t
                    * Mina_base.Zkapp_statement.Stable.Latest.t
                    * Pickles.Side_loaded.Proof.Stable.Latest.t )
                    list
                  | invalid ]
                  list]
              , verify_commands )
        ; get_blockchain_verification_key =
            f
              ( [%bin_type_class: unit]
              , [%bin_type_class: Pickles.Verification_key.Stable.Latest.t]
              , get_blockchain_verification_key )
        ; toggle_internal_tracing =
            f
              ( [%bin_type_class: bool]
              , [%bin_type_class: unit]
              , toggle_internal_tracing )
        ; set_itn_logger_data =
            f
              ( [%bin_type_class: int]
              , [%bin_type_class: unit]
              , set_itn_logger_data )
        }

      let init_worker_state
          Worker_state.
            { conf_dir
            ; enable_internal_tracing
            ; internal_trace_filename
            ; logger
            ; proof_level
            ; constraint_constants
            } =
        if Option.is_some conf_dir then (
          let max_size = 256 * 1024 * 512 in
          let num_rotate = 1 in
          Logger.Consumer_registry.register ~id:"default"
            ~processor:(Logger.Processor.raw ())
            ~transport:
              (Logger_file_system.dumb_logrotate
                 ~directory:(Option.value_exn conf_dir)
                 ~log_filename:"mina-verifier.log" ~max_size ~num_rotate ) ;
          Option.iter internal_trace_filename ~f:(fun log_filename ->
              Itn_logger.set_message_postprocessor
                Internal_tracing.For_itn_logger.post_process_message ;
              Logger.Consumer_registry.register ~id:Logger.Logger_id.mina
                ~processor:Internal_tracing.For_logger.processor
                ~transport:
                  (Logger_file_system.dumb_logrotate
                     ~directory:(Option.value_exn conf_dir ^ "/internal-tracing")
                     ~log_filename
                     ~max_size:(1024 * 1024 * 10)
                     ~num_rotate:50 ) ) ) ;
        if enable_internal_tracing then
          don't_wait_for @@ Internal_tracing.toggle ~logger `Enabled ;
        [%log info] "Verifier started" ;
        Worker_state.create
          { conf_dir
          ; enable_internal_tracing
          ; internal_trace_filename
          ; logger
          ; proof_level
          ; constraint_constants
          }

      let init_connection_state ~connection:_ ~worker_state:_ () = Deferred.unit
    end
  end

  include Rpc_parallel.Make (T)
end

type worker =
  { connection : Worker.Connection.t
  ; process : Process.t
  ; exit_or_signal : Unix.Exit_or_signal.t Deferred.Or_error.t
  }

type t = { worker : worker Ivar.t ref; logger : Logger.Stable.Latest.t }

(* TODO: investigate why conf_dir wasn't being used *)
let create ~logger ?(enable_internal_tracing = false) ?internal_trace_filename
    ~proof_level ~constraint_constants ~pids ~conf_dir () : t Deferred.t =
  let on_failure err =
    [%log error] "Verifier process failed with error $err"
      ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
    Error.raise err
  in
  let create_worker () =
    [%log info] "Starting a new verifier process" ;
    let%map.Deferred.Or_error connection, process =
      (* This [try_with] isn't really here to catch an error that throws while
         the process is being spawned. Indeed, the immediate [ok_exn] will
         ensure that any errors that occur during that time are immediately
         re-raised.
         However, this *also* captures any exceptions raised by code scheduled
         as a result of the inner calls, but which have not completed by the
         time the process has been created.
         In order to suppress errors around [wait]s coming from [Rpc_parallel]
         -- in particular the "no child processes" WNOHANG error -- we supply a
         [rest] handler for the 'rest' of the errors after the value is
         determined, which logs the errors and then swallows them.
      *)
      Monitor.try_with ~name:"Verifier RPC worker" ~here:[%here] ~run:`Now
        ~rest:
          (`Call
            (fun exn ->
              let err = Error.of_exn ~backtrace:`Get exn in
              [%log error] "Error from verifier worker $err"
                ~metadata:[ ("err", Error_json.error_to_yojson err) ] ) )
        (fun () ->
          Worker.spawn_in_foreground_exn
            ~connection_timeout:(Time.Span.of_min 1.) ~on_failure
            ~shutdown_on:Connection_closed ~connection_state_init_arg:()
            { conf_dir
            ; enable_internal_tracing
            ; internal_trace_filename
            ; logger
            ; proof_level
            ; constraint_constants
            } )
      |> Deferred.Result.map_error ~f:Error.of_exn
    in
    Child_processes.Termination.wait_for_process_log_errors ~logger process
      ~module_:__MODULE__ ~location:__LOC__ ~here:[%here] ;
    let exit_or_signal =
      Child_processes.Termination.wait_safe ~logger process ~module_:__MODULE__
        ~location:__LOC__ ~here:[%here]
    in
    [%log info]
      "Daemon started process of kind $process_kind with pid $verifier_pid"
      ~metadata:
        [ ("verifier_pid", `Int (Process.pid process |> Pid.to_int))
        ; ( "process_kind"
          , `String Child_processes.Termination.(show_process_kind Verifier) )
        ] ;
    Child_processes.Termination.register_process pids process
      Child_processes.Termination.Verifier ;
    (* Always report termination as expected, and use the restart logic here
       instead.
    *)
    don't_wait_for
    @@ Pipe.iter
         (Process.stdout process |> Reader.pipe)
         ~f:(fun stdout ->
           return
           @@ [%log debug] "Verifier stdout: $stdout"
                ~metadata:[ ("stdout", `String stdout) ] ) ;
    don't_wait_for
    @@ Pipe.iter
         (Process.stderr process |> Reader.pipe)
         ~f:(fun stderr ->
           return
           @@ [%log error] "Verifier stderr: $stderr"
                ~metadata:[ ("stderr", `String stderr) ] ) ;
    { connection; process; exit_or_signal }
  in
  let%map worker = create_worker () |> Deferred.Or_error.ok_exn in
  let worker_ref = ref (Ivar.create_full worker) in
  let rec on_worker { connection = _; process; exit_or_signal } =
    let finished =
      Deferred.any
        [ ( exit_or_signal
          >>| function
          | Ok _ ->
              `Unexpected_termination
          | Error err ->
              `Wait_threw_an_exception err )
        ]
    in
    upon finished (fun e ->
        don't_wait_for (Process.stdin process |> Writer.close) ;
        let pid = Process.pid process in
        Child_processes.Termination.remove pids pid ;
        let create_worker_trigger = Ivar.create () in
        don't_wait_for
          (* If we don't hear back that the process has died after 10 seconds,
             begin creating a new process anyway.
          *)
          (let%map () = after (Time.Span.of_sec 10.) in
           Ivar.fill_if_empty create_worker_trigger () ) ;
        let () =
          match e with
          | `Unexpected_termination ->
              [%log error] "verifier terminated unexpectedly"
                ~metadata:[ ("verifier_pid", `Int (Pid.to_int pid)) ] ;
              Ivar.fill_if_empty create_worker_trigger ()
          | `Wait_threw_an_exception _ -> (
              ( match e with
              | `Wait_threw_an_exception err ->
                  [%log info]
                    "Saw an exception while trying to wait for the verifier \
                     process: $exn"
                    ~metadata:[ ("exn", Error_json.error_to_yojson err) ]
              | _ ->
                  () ) ;
              match Signal.send Signal.kill (`Pid pid) with
              | `No_such_process ->
                  [%log info] "verifier failed to get sigkill (no such process)"
                    ~metadata:[ ("verifier_pid", `Int (Pid.to_int pid)) ] ;
                  Ivar.fill_if_empty create_worker_trigger ()
              | `Ok ->
                  [%log info] "verifier successfully got sigkill"
                    ~metadata:[ ("verifier_pid", `Int (Pid.to_int pid)) ] )
        in
        let new_worker = Ivar.create () in
        worker_ref := new_worker ;
        don't_wait_for
          (let%map exit_metadata =
             match%map exit_or_signal with
             | Ok res ->
                 [ ( "exit_status"
                   , `String (Unix.Exit_or_signal.to_string_hum res) )
                 ]
             | Error err ->
                 [ ("exit_status", `String "Unknown: wait threw an error")
                 ; ("exn", Error_json.error_to_yojson err)
                 ]
           in
           [%log info] "verifier successfully stopped"
             ~metadata:
               ( ("verifier_pid", `Int (Process.pid process |> Pid.to_int))
               :: exit_metadata ) ;
           Child_processes.Termination.remove pids pid ;
           Ivar.fill_if_empty create_worker_trigger () ) ;
        don't_wait_for
          (let%bind () = Ivar.read create_worker_trigger in
           let rec try_create_worker () =
             match%bind create_worker () with
             | Ok worker ->
                 on_worker worker ;
                 Ivar.fill new_worker worker ;
                 return ()
             | Error err ->
                 [%log error]
                   "Failed to create a new verifier process: $err. Retrying..."
                   ~metadata:[ ("err", Error_json.error_to_yojson err) ] ;
                 (* Wait 5s before retrying. *)
                 let%bind () = after Time.Span.(of_sec 5.) in
                 try_create_worker ()
           in
           try_create_worker () ) )
  in
  on_worker worker ;
  { worker = worker_ref; logger }

let with_retry ~logger f =
  let pause = Time.Span.of_sec 5. in
  let rec go attempts_remaining =
    [%log trace] "Verifier trying with $attempts_remaining"
      ~metadata:[ ("attempts_remaining", `Int attempts_remaining) ] ;
    match%bind f () with
    | Ok (`Continue x) ->
        return (Ok x)
    | Ok (`Stop e) ->
        return (Error e)
    | Error e ->
        if attempts_remaining = 0 then return (Error e)
        else
          let%bind () = after pause in
          go (attempts_remaining - 1)
  in
  go 4

let verify_blockchain_snarks { worker; logger } chains =
  O1trace.thread "dispatch_blockchain_snark_verification" (fun () ->
      with_retry ~logger (fun () ->
          let%bind { connection; _ } =
            let ivar = !worker in
            match Ivar.peek ivar with
            | Some worker ->
                Deferred.return worker
            | None ->
                [%log debug] "Waiting for the verifier process to restart" ;
                let%map worker = Ivar.read ivar in
                [%log debug] "Verifier process has restarted; finished waiting" ;
                worker
          in
          Deferred.any
            [ ( after (Time.Span.of_min 3.)
              >>| fun _ ->
              Or_error.return
              @@ `Stop (Error.of_string "verify_blockchain_snarks timeout") )
            ; Worker.Connection.run connection
                ~f:Worker.functions.verify_blockchains ~arg:chains
              |> Deferred.Or_error.map ~f:(fun x -> `Continue x)
            ] ) )

let verify_transaction_snarks { worker; logger } ts =
  O1trace.thread "dispatch_transaction_snark_verification" (fun () ->
      let n = List.length ts in
      let metadata = [ ("n", `Int n) ] in
      [%log trace] "verify $n transaction_snarks (before)" ~metadata ;
      let%map res =
        with_retry ~logger (fun () ->
            let%bind { connection; _ } = Ivar.read !worker in
            Worker.Connection.run connection
              ~f:Worker.functions.verify_transaction_snarks ~arg:ts
            |> Deferred.Or_error.map ~f:(fun x -> `Continue x) )
      in
      let res_json =
        match res with
        | Ok (Ok ()) ->
            `String "ok"
        | Error err ->
            Error_json.error_to_yojson (Error.tag ~tag:"Verifier issue" err)
        | Ok (Error err) ->
            Error_json.error_to_yojson err
      in
      [%log trace] "verify $n transaction_snarks (after)!"
        ~metadata:(("result", res_json) :: metadata) ;
      res )

(* Wrappers for internal_tracing *)

let wrap_verify_snarks_with_trace ~checkpoint_before ~checkpoint_after
    verify_function t to_verify =
  let logger = t.logger in
  let count = List.length to_verify in
  let open Deferred.Let_syntax in
  [%log internal] checkpoint_before ~metadata:[ ("count", `Int count) ] ;
  let%map result = verify_function t to_verify in
  [%log internal] checkpoint_after ;
  ( match result with
  | Error err | Ok (Error err) ->
      [%log internal] "@metadata"
        ~metadata:[ ("failure", `String (Error.to_string_hum err)) ]
  | _ ->
      () ) ;
  result

let verify_blockchain_snarks =
  wrap_verify_snarks_with_trace ~checkpoint_before:"Verify_blockchain_snarks"
    ~checkpoint_after:"Verify_blockchain_snarks_done" verify_blockchain_snarks

let verify_transaction_snarks =
  wrap_verify_snarks_with_trace ~checkpoint_before:"Verify_transaction_snarks"
    ~checkpoint_after:"Verify_transaction_snarks_done" verify_transaction_snarks

let verify_commands { worker; logger } ts =
  O1trace.thread "dispatch_user_command_verification" (fun () ->
      with_retry ~logger (fun () ->
          let%bind { connection; _ } = Ivar.read !worker in
          Worker.Connection.run connection ~f:Worker.functions.verify_commands
            ~arg:ts
          |> Deferred.Or_error.map ~f:(fun x -> `Continue x) ) )

let verify_commands t ts =
  let logger = t.logger in
  let count = List.length ts in
  let open Deferred.Let_syntax in
  [%log internal] "Verify_commands" ~metadata:[ ("count", `Int count) ] ;
  let%map result = verify_commands t ts in
  [%log internal] "Verify_commands_done" ;
  result

let get_blockchain_verification_key { worker; logger } =
  O1trace.thread "dispatch_blockchain_verification_key" (fun () ->
      with_retry ~logger (fun () ->
          let%bind { connection; _ } = Ivar.read !worker in
          Worker.Connection.run connection
            ~f:Worker.functions.get_blockchain_verification_key ~arg:()
          |> Deferred.Or_error.map ~f:(fun x -> `Continue x) ) )

let toggle_internal_tracing { worker; logger } enabled =
  with_retry ~logger (fun () ->
      let%bind { connection; _ } = Ivar.read !worker in
      Worker.Connection.run connection
        ~f:Worker.functions.toggle_internal_tracing ~arg:enabled
      |> Deferred.Or_error.map ~f:(fun x -> `Continue x) )

let set_itn_logger_data { worker; logger } ~daemon_port =
  with_retry ~logger (fun () ->
      let%bind { connection; _ } = Ivar.read !worker in
      Worker.Connection.run connection ~f:Worker.functions.set_itn_logger_data
        ~arg:daemon_port
      |> Deferred.Or_error.map ~f:(fun x -> `Continue x) )
