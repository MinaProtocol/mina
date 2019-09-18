open Async
open Core_kernel

let pid_set = Pid.Hash_set.create ()

let register_process process = Hash_set.add pid_set (Process.pid process)

let check_terminated_pid child_pid logger =
  if Hash_set.mem pid_set child_pid then (
    Logger.error logger ~module_:__MODULE__ ~location:__LOC__
      "Child process with pid $child_pid has terminated; terminating parent \
       process $pid"
      ~metadata:[("child_pid", `Int (Pid.to_int child_pid))] ;
    Core_kernel.exit 99 )
