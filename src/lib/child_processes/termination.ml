(* termination.ml -- maintain a set of child pids
   when a child not expected to terminate does terminate, raise an exception
*)

open Async
open Core_kernel
include Hashable.Make_binable (Pid)

type process_kind =
  | Prover
  | Verifier
  | Libp2p_helper
  | Snark_worker
  | Uptime_snark_worker
  | Vrf_evaluator
[@@deriving show { with_path = false }, yojson]

type t = process_kind Pid.Table.t

let create_pid_table () : t = Pid.Table.create ()

let register_process (t : t) process kind =
  Pid.Table.add_exn t ~key:(Process.pid process) ~data:kind

let remove : t -> Pid.t -> unit = Pid.Table.remove

(** for some signals that cause termination, offer a possible explanation *)
let get_signal_cause_opt =
  let open Signal in
  let signal_causes_tbl : string Table.t = Table.create () in
  List.iter
    [ (kill, "Process killed because out of memory")
    ; (int, "Process interrupted by user or other program")
    ]
    ~f:(fun (signal, msg) ->
      Base.ignore (Table.add signal_causes_tbl ~key:signal ~data:msg) ) ;
  fun signal -> Signal.Table.find signal_causes_tbl signal

(** wait for a [process], which may resolve immediately or in a Deferred.t,
    log any errors, attributing the source to the provided [module] and [location]
*)
let wait_for_process_log_errors ~logger process ~module_ ~location ~here =
  (* Handle implicit raciness in the wait syscall by calling [Process.wait]
     early, so that its value will be correctly cached when we actually need
     it.
  *)
  match
    Or_error.try_with (fun () ->
        (* Eagerly force [Process.wait], so that it won't be captured
           elsewhere on exit.
        *)
        let waiting =
          Monitor.try_with ~here ~run:`Now
            ~rest:
              (`Call
                (fun exn ->
                  let err = Error.of_exn exn in
                  Logger.error logger ~module_ ~location
                    "Saw a deferred exception $exn after waiting for process"
                    ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ) )
            (fun () -> Process.wait process)
        in
        don't_wait_for
          ( match%map waiting with
          | Ok _ ->
              ()
          | Error exn ->
              let err = Error.of_exn exn in
              Logger.error logger ~module_ ~location
                "Saw a deferred exception $exn while waiting for process"
                ~metadata:[ ("exn", Error_json.error_to_yojson err) ] ) )
  with
  | Ok _ ->
      ()
  | Error err ->
      Logger.error logger ~module_ ~location
        "Saw an immediate exception $exn while waiting for process"
        ~metadata:[ ("exn", Error_json.error_to_yojson err) ]

(** Call this as early as possible after the process is known, and store the
    resulting [Deferred.t] somewhere to be used later.
*)
let wait_safe ~logger process ~module_ ~location ~here =
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
        let deferred_wait =
          Monitor.try_with ~here ~run:`Now
            ~rest:
              (`Call
                (fun exn ->
                  Logger.warn logger ~module_ ~location
                    "Saw an error from Process.wait in wait_safe: $err"
                    ~metadata:
                      [ ("err", Error_json.error_to_yojson (Error.of_exn exn)) ]
                  ) )
            (fun () -> Process.wait process)
        in
        Deferred.Result.map_error ~f:Error.of_exn deferred_wait )
  with
  | Ok x ->
      x
  | Error err ->
      Deferred.Or_error.fail err
