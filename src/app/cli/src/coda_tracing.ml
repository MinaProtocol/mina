open Core
open Async

(** Start tracing, writing the trace output to [conf_dir ^/ (current_pid ^ ".trace")]. *)
let start conf_dir =
  Writer.open_file ~append:true
    (conf_dir ^/ sprintf "%d.trace" (Unix.getpid () |> Pid.to_int))
  >>| O1trace.start_tracing

(** Stop tracing. *)
let stop () = O1trace.stop_tracing ()
