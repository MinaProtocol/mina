open Core
open Async
open Spawner

module Pid_worker = struct
  type t = {reader: int Pipe.Reader.t; writer: int Pipe.Writer.t}

  type input = unit [@@deriving bin_io]

  type state = int [@@deriving bin_io]

  let create () =
    let reader, writer = Pipe.create () in
    return @@ {reader; writer}

  let new_states {reader} = reader

  let run t =
    let pid = Pid.to_int @@ Unix.getpid () in
    Pipe.write t.writer pid
end

module Worker = Parallel_worker.Make (Pid_worker)
module Master = Master.Make (Worker (Int)) (Int)

let master_command =
  let open Command.Let_syntax in
  let%map {host; executable_path} = Command_util.config_arguments in
  fun () ->
    let open Deferred.Let_syntax in
    let open Master in
    let t = create () in
    let config = {Spawner.Config.id= 1; host; executable_path}
    and process1 = 1
    and process2 = 2 in
    let%bind () = add t () process1 ~config
    and () = add t () process2 ~config in
    let%bind () = Option.value_exn (run t process1)
    and () = Option.value_exn (run t process2) in
    let reader = new_states t in
    let%map _, pid1 = Linear_pipe.read_exn reader
    and _, pid2 = Linear_pipe.read_exn reader in
    assert (pid1 <> pid2)

let name = "different-pid"

let command =
  Command.async master_command
    ~summary:
      "Tests that running multiple parallel workers run in different processes"
