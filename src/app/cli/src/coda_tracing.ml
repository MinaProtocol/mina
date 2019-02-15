open Core
open Async

(** [start dir] starts writing the trace output to [dir ^/ (current_pid ^ ".trace")]. *)
let start dir =
  O1trace.forget_tid (fun () ->
  Writer.open_file ~append:true
    (dir ^/ sprintf "%d.trace" (Unix.getpid () |> Pid.to_int))
  >>| O1trace.start_tracing)

(** Stop tracing. *)
let stop () = O1trace.stop_tracing ()
