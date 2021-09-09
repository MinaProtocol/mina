(* prod.ml *)

open Core_kernel
open Async
open Mina_base
open Mina_state
open Blockchain_snark

type ledger_proof = Ledger_proof.Prod.t

module Worker_state = struct
  module type S = sig
    val verify_blockchain_snarks :
      (Protocol_state.Value.t * Proof.t) list -> bool

    val verify_commands :
         Mina_base.User_command.Verifiable.t list
      -> [ `Valid of Mina_base.User_command.Valid.t
         | `Invalid
         | `Valid_assuming of
           ( Pickles.Side_loaded.Verification_key.t
           * Mina_base.Snapp_statement.t
           * Pickles.Side_loaded.Proof.t )
           list ]
         list

    val verify_transaction_snarks :
      (Transaction_snark.t * Sok_message.t) list -> bool
  end

  (* bin_io required by rpc_parallel *)
  type init_arg =
    { conf_dir: string option
    ; logger: Logger.Stable.Latest.t
    ; proof_level: Genesis_constants.Proof_level.Stable.Latest.t }
  [@@deriving bin_io_unversioned]

  type t = (module S)

  let create {logger; proof_level; _} : t Deferred.t =
    Memory_stats.log_memory_stats logger ~process:"verifier" ;
    match proof_level with
    | Full ->
        Deferred.return
          (let bc_vk = Precomputed_values.blockchain_verification ()
           and tx_vk = Precomputed_values.transaction_verification () in
           let module M = struct
             let verify_commands (cs : User_command.Verifiable.t list) : _ list
                 =
               let cs = List.map cs ~f:Common.check in
               let to_verify =
                 List.concat_map cs ~f:(function
                   | `Valid _ ->
                       []
                   | `Invalid ->
                       []
                   | `Valid_assuming (_, xs) ->
                       xs )
               in
               let all_verified =
                 Pickles.Side_loaded.verify
                   ~value_to_field_elements:Snapp_statement.to_field_elements
                   to_verify
               in
               List.map cs ~f:(function
                 | `Valid c ->
                     `Valid c
                 | `Invalid ->
                     `Invalid
                 | `Valid_assuming (c, xs) ->
                     if all_verified then `Valid c else `Valid_assuming xs )

             let verify_blockchain_snarks ts =
               Blockchain_snark.Blockchain_snark_state.verify ts ~key:bc_vk

             let verify_transaction_snarks ts =
               match
                 Or_error.try_with (fun () ->
                     Transaction_snark.verify ~key:tx_vk ts )
               with
               | Ok result ->
                   result
               | Error e ->
                   [%log error]
                     ~metadata:[("error", Error_json.error_to_yojson e)]
                     "Verifier threw an exception while verifying transaction \
                      snark" ;
                   failwith "Verifier crashed"
           end in
           (module M : S))
    | Check | None ->
        Deferred.return
        @@ ( module struct
             let verify_commands cs =
               List.map cs ~f:(fun c ->
                   match Common.check c with
                   | `Valid c ->
                       `Valid c
                   | `Invalid ->
                       `Invalid
                   | `Valid_assuming (c, _) ->
                       `Valid c )

             let verify_blockchain_snarks _ = true

             let verify_transaction_snarks _ = true
           end
           : S )

  let get = Fn.id
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { verify_blockchains: ('w, Blockchain.t list, bool) F.t
      ; verify_transaction_snarks:
          ('w, (Transaction_snark.t * Sok_message.t) list, bool) F.t
      ; verify_commands:
          ( 'w
          , User_command.Verifiable.t list
          , [ `Valid of User_command.Valid.t
            | `Invalid
            | `Valid_assuming of
              ( Pickles.Side_loaded.Verification_key.t
              * Mina_base.Snapp_statement.t
              * Pickles.Side_loaded.Proof.t )
              list ]
            list )
          F.t }

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
      let verify_blockchains (w : Worker_state.t) (chains : Blockchain.t list)
          =
        let (module M) = Worker_state.get w in
        Deferred.return
          (M.verify_blockchain_snarks
             (List.map chains ~f:(fun snark ->
                  ( Blockchain_snark.Blockchain.state snark
                  , Blockchain_snark.Blockchain.proof snark ) )))

      let verify_transaction_snarks (w : Worker_state.t) ts =
        let (module M) = Worker_state.get w in
        Deferred.return (M.verify_transaction_snarks ts)

      let verify_commands (w : Worker_state.t) ts =
        let (module M) = Worker_state.get w in
        Deferred.return (M.verify_commands ts)

      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state:_ i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        { verify_blockchains=
            f
              ( [%bin_type_class: Blockchain.Stable.Latest.t list]
              , Bool.bin_t
              , verify_blockchains )
        ; verify_transaction_snarks=
            f
              ( [%bin_type_class:
                  ( Transaction_snark.Stable.Latest.t
                  * Sok_message.Stable.Latest.t )
                  list]
              , Bool.bin_t
              , verify_transaction_snarks )
        ; verify_commands=
            f
              ( [%bin_type_class: User_command.Verifiable.Stable.Latest.t list]
              , [%bin_type_class:
                  [ `Valid of User_command.Valid.Stable.Latest.t
                  | `Invalid
                  | `Valid_assuming of
                    ( Pickles.Side_loaded.Verification_key.Stable.Latest.t
                    * Mina_base.Snapp_statement.Stable.Latest.t
                    * Pickles.Side_loaded.Proof.Stable.Latest.t )
                    list ]
                  list]
              , verify_commands ) }

      let init_worker_state Worker_state.{conf_dir; logger; proof_level} =
        ( if Option.is_some conf_dir then
          let max_size = 256 * 1024 * 512 in
          let num_rotate = 1 in
          Logger.Consumer_registry.register ~id:"default"
            ~processor:(Logger.Processor.raw ())
            ~transport:
              (Logger.Transport.File_system.dumb_logrotate
                 ~directory:(Option.value_exn conf_dir)
                 ~log_filename:"mina-verifier.log" ~max_size ~num_rotate) ) ;
        [%log info] "Verifier started" ;
        Worker_state.create {conf_dir; logger; proof_level}

      let init_connection_state ~connection:_ ~worker_state:_ () =
        Deferred.unit
    end
  end

  include Rpc_parallel.Make (T)
end

type worker =
  { connection: Worker.Connection.t
  ; process: Process.t
  ; exit_or_signal: Unix.Exit_or_signal.t Deferred.Or_error.t }

type t = {worker: worker Ivar.t ref; logger: Logger.Stable.Latest.t}

let plus_or_minus initial ~delta =
  initial +. (Random.float (2. *. delta) -. delta)

let min_expected_lifetime = Time.Span.of_min 1.

(** Call this as early as possible after the process is known, and store the
    resulting [Deferred.t] somewhere to be used later.
*)
let wait_safe process =
  (* This is a little more nuanced than it may initially seem.
     - The initial call to [Process.wait] runs a wait syscall -- with the
       NOHANG flag -- synchronously.
       * This may raise an error (WNOHANG or otherwise) that we have to handle
         synchronously at call time.
     - The [Process.wait] then returns a [Deferred.t] that resolves when a
       second syscall returns.
       * This may throw its own errors, so we need to ensure that this is also
         wrapped to catch them.
     - Once the child process has died and one or more wait syscalls have
       resolved, the operating system will drop the process metadata. This
       means that our wait may hang forever if 1) the process has already died
       and 2) there was a wait call issued by some other code before we have a
       chance.
       * Thus, we should make this initial call while the child process is
         still alive, preferably on startup, to avoid this hang.
  *)
  match
    Or_error.try_with (fun () ->
        let deferred_wait = Process.wait process in
        Deferred.Or_error.try_with (fun () -> deferred_wait) )
  with
  | Ok x ->
      x
  | Error err ->
      Deferred.Or_error.fail err

(* TODO: investigate why conf_dir wasn't being used *)
let create ~logger ~proof_level ~pids ~conf_dir : t Deferred.t =
  let on_failure err =
    [%log error] "Verifier process failed with error $err"
      ~metadata:[("err", Error_json.error_to_yojson err)] ;
    Error.raise err
  in
  let prev_start = ref (Time.of_span_since_epoch Time.Span.zero) in
  let create_worker () =
    let now = Time.now () in
    let prev_died_early =
      Time.Span.( < ) (Time.diff now !prev_start) min_expected_lifetime
    in
    prev_start := now ;
    let%map connection, process =
      Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
        ~on_failure ~shutdown_on:Disconnect ~connection_state_init_arg:()
        {conf_dir; logger; proof_level}
    in
    let exit_or_signal = wait_safe process in
    [%log info]
      "Daemon started process of kind $process_kind with pid $verifier_pid"
      ~metadata:
        [ ("verifier_pid", `Int (Process.pid process |> Pid.to_int))
        ; ( "process_kind"
          , `String Child_processes.Termination.(show_process_kind Verifier) )
        ] ;
    if prev_died_early then
      Child_processes.Termination.register_process pids process
        Child_processes.Termination.Verifier ;
    don't_wait_for
    @@ Pipe.iter
         (Process.stdout process |> Reader.pipe)
         ~f:(fun stdout ->
           return
           @@ [%log debug] "Verifier stdout: $stdout"
                ~metadata:[("stdout", `String stdout)] ) ;
    don't_wait_for
    @@ Pipe.iter
         (Process.stderr process |> Reader.pipe)
         ~f:(fun stderr ->
           return
           @@ [%log error] "Verifier stderr: $stderr"
                ~metadata:[("stderr", `String stderr)] ) ;
    {connection; process; exit_or_signal}
  in
  let%map worker = create_worker () in
  let worker_ref = ref (Ivar.create_full worker) in
  let rec on_worker {connection= _; process; exit_or_signal} =
    let restart_after = Time.Span.(of_min (15. |> plus_or_minus ~delta:2.5)) in
    let finished =
      Deferred.any
        [ (after restart_after >>| fun () -> `Time_to_restart)
        ; ( exit_or_signal
          >>| function
          | Ok _ ->
              `Unexpected_termination
          | Error err ->
              `Wait_threw_an_exception err ) ]
    in
    upon finished (fun e ->
        let pid = Process.pid process in
        let () =
          match e with
          | `Unexpected_termination ->
              [%log error] "verifier terminated unexpectedly"
                ~metadata:[("verifier_pid", `Int (Pid.to_int pid))]
          | `Time_to_restart | `Wait_threw_an_exception _ -> (
              ( match e with
              | `Wait_threw_an_exception err ->
                  [%log info]
                    "Saw an exception while trying to wait for the verifier \
                     process: $exn"
                    ~metadata:[("exn", Error_json.error_to_yojson err)]
              | _ ->
                  () ) ;
              Child_processes.Termination.mark_termination_as_expected pids pid ;
              match Signal.send Signal.kill (`Pid pid) with
              | `No_such_process ->
                  [%log info]
                    "verifier failed to get sigkill (no such process)"
                    ~metadata:[("verifier_pid", `Int (Pid.to_int pid))]
              | `Ok ->
                  [%log info] "verifier successfully got sigkill"
                    ~metadata:[("verifier_pid", `Int (Pid.to_int pid))] )
        in
        let new_worker = Ivar.create () in
        worker_ref := new_worker ;
        don't_wait_for
        @@ let%bind exit_metadata =
             match%map exit_or_signal with
             | Ok res ->
                 [ ( "exit_status"
                   , `String (Unix.Exit_or_signal.to_string_hum res) ) ]
             | Error err ->
                 [ ("exit_status", `String "Unknown: wait threw an error")
                 ; ("exn", Error_json.error_to_yojson err) ]
           in
           [%log info] "verifier successfully stopped"
             ~metadata:
               ( ("verifier_pid", `Int (Process.pid process |> Pid.to_int))
               :: exit_metadata ) ;
           Child_processes.Termination.remove pids pid ;
           let%map worker = create_worker () in
           on_worker worker ;
           Ivar.fill new_worker worker )
  in
  on_worker worker ;
  {worker= worker_ref; logger}

let with_retry ~logger f =
  let pause = Time.Span.of_sec 5. in
  let rec go attempts_remaining =
    [%log trace] "Verifier trying with $attempts_remaining"
      ~metadata:[("attempts_remaining", `Int attempts_remaining)] ;
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

let verify_blockchain_snarks {worker; logger} chains =
  with_retry ~logger (fun () ->
      let%bind {connection; _} =
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
          |> Deferred.Or_error.map ~f:(fun x -> `Continue x) ] )

module Id = Unique_id.Int ()

let verify_transaction_snarks {worker; logger} ts =
  let id = Id.create () in
  let n = List.length ts in
  let metadata () =
    ("id", `String (Id.to_string id))
    :: ("n", `Int n)
    :: Memory_stats.(jemalloc_memory_stats () @ ocaml_memory_stats ())
  in
  [%log trace] "verify $n transaction_snarks (before)" ~metadata:(metadata ()) ;
  let res =
    with_retry ~logger (fun () ->
        let%bind {connection; _} = Ivar.read !worker in
        Worker.Connection.run connection
          ~f:Worker.functions.verify_transaction_snarks ~arg:ts
        |> Deferred.Or_error.map ~f:(fun x -> `Continue x) )
  in
  upon res (fun x ->
      [%log trace] "verify $n transaction_snarks (after)"
        ~metadata:
          ( ("result", `String (Sexp.to_string ([%sexp_of: bool Or_error.t] x)))
          :: metadata () ) ) ;
  res

let verify_commands {worker; logger} ts =
  with_retry ~logger (fun () ->
      let%bind {connection; _} = Ivar.read !worker in
      Worker.Connection.run connection ~f:Worker.functions.verify_commands
        ~arg:ts
      |> Deferred.Or_error.map ~f:(fun x -> `Continue x) )
