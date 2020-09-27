(* termination.ml -- maintain a set of child pids
   when a child terminates, terminate the current process
*)

open Async
open Core_kernel
include Hashable.Make_binable (Pid)

type process_kind = Prover | Verifier [@@deriving show {with_path= false}]

type data = {kind: process_kind; termination_expected: bool}

type t = data Pid.Table.t

let create_pid_table () : t = Pid.Table.create ()

let register_process ?(termination_expected = false) (t : t) process kind =
  let data = {kind; termination_expected} in
  Pid.Table.add_exn t ~key:(Process.pid process) ~data

let mark_termination_as_expected t child_pid =
  Pid.Table.change t child_pid
    ~f:(Option.map ~f:(fun r -> {r with termination_expected= true}))

let remove : t -> Pid.t -> unit = Pid.Table.remove

let check_terminated_child (t : t) child_pid logger =
  if Pid.Table.mem t child_pid then
    let data = Pid.Table.find_exn t child_pid in
    if not data.termination_expected then (
      [%log error]
        "Child process of kind $process_kind with pid $child_pid has terminated"
        ~metadata:
          [ ("child_pid", `Int (Pid.to_int child_pid))
          ; ("process_kind", `String (show_process_kind data.kind)) ] ;
      Core_kernel.exit 99 )
