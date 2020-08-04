(* termination.ml -- maintain a set of child pids
   when a child terminates, terminate the current process
*)

open Async
open Core_kernel
include Hashable.Make_binable (Pid)

type process_kind = Prover | Verifier [@@deriving show {with_path= false}]

type t = process_kind Pid.Table.t

let create_pid_table () = Pid.Table.create ()

let register_process t process kind =
  Pid.Table.add_exn t ~key:(Process.pid process) ~data:kind

let check_terminated_child t child_pid logger =
  if Pid.Table.mem t child_pid then (
    let kind = Pid.Table.find_exn t child_pid in
    [%log error]
      "Child process of kind $process_kind with pid $child_pid has terminated"
      ~metadata:
        [ ("child_pid", `Int (Pid.to_int child_pid))
        ; ("process_kind", `String (show_process_kind kind)) ] ;
    Core_kernel.exit 99 )
