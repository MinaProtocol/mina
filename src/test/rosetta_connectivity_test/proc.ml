(* Child processes of the test: one-shot commands, and long-running services
   whose stdout and stderr go to a log file. *)

open Core
open Async

let log fmt =
  ksprintf (fun s -> printf "%s %s\n%!" (Time.to_string (Time.now ())) s) fmt

let run ?env ?(working_dir = ".") prog args =
  log "$ %s %s" prog (String.concat ~sep:" " args) ;
  Process.run ?env ~working_dir ~prog ~args ()

let run_exn ?env ?working_dir prog args =
  run ?env ?working_dir prog args >>| Or_error.ok_exn

(* Runs [prog] to completion with its output in [log_file] rather than in
   memory: psql restoring a dump prints one line per statement. *)
let run_logged ?env ~log_file prog args =
  log "$ %s %s (output: %s)" prog (String.concat ~sep:" " args) log_file ;
  let%bind process = Process.create_exn ?env ~prog ~args () in
  let%bind writer = Writer.open_file ~append:true log_file in
  let drain reader =
    Pipe.iter_without_pushback (Reader.pipe reader) ~f:(Writer.write writer)
  in
  let%bind () =
    Deferred.all_unit
      [ drain (Process.stdout process); drain (Process.stderr process) ]
  in
  let%bind exit_status = Process.wait process in
  let%map () = Writer.close writer in
  match exit_status with
  | Ok () ->
      Ok ()
  | Error _ as e ->
      Or_error.errorf "%s failed (%s), see %s" prog
        (Unix.Exit_or_signal.to_string_hum e)
        log_file

type service = { name : string; process : Process.t; log_file : string }

let pid t = Process.pid t.process |> Pid.to_int

let spawn ?env ~name ~log_file prog args =
  log "starting %s: %s %s (log: %s)" name prog
    (String.concat ~sep:" " args)
    log_file ;
  let%bind process = Process.create_exn ?env ~prog ~args () in
  let%map writer = Writer.open_file ~append:true log_file in
  let drain reader =
    Pipe.iter_without_pushback (Reader.pipe reader) ~f:(Writer.write writer)
  in
  don't_wait_for
    (let%bind () =
       Deferred.all_unit
         [ drain (Process.stdout process); drain (Process.stderr process) ]
     in
     Writer.close writer ) ;
  { name; process; log_file }

(* Async reaps its children, so an exited one is gone from [Process.wait]
   rather than a zombie; signal 0 would still find a zombie "running". *)
let is_running t = Option.is_none (Deferred.peek (Process.wait t.process))

(* SIGTERM, then SIGKILL after [grace]. *)
let stop ?(grace = Time.Span.of_sec 10.) t =
  if not (is_running t) then return ()
  else (
    log "stopping %s (pid %d)" t.name (pid t) ;
    Process.send_signal t.process Signal.term ;
    match%bind Clock.with_timeout grace (Process.wait t.process) with
    | `Result _ ->
        return ()
    | `Timeout ->
        Process.send_signal t.process Signal.kill ;
        Process.wait t.process >>| ignore )

let rss_mib t = Mina_automation.Utils.get_memory_usage_mib (pid t)
