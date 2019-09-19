(* termination.ml -- maintain a set of child pids
   when a child terminates, terminate the current process
*)

open Async
open Core_kernel

type t = Pid.Hash_set.t

let create_pid_set () = Pid.Hash_set.create ()

let register_process t process = Hash_set.add t (Process.pid process)

let check_terminated_child t child_pid logger =
  if Hash_set.mem t child_pid then (
    Logger.error logger ~module_:__MODULE__ ~location:__LOC__
      "Child process with pid $child_pid has terminated; terminating parent \
       process $pid"
      ~metadata:[("child_pid", `Int (Pid.to_int child_pid))] ;
    Core_kernel.exit 99 )
