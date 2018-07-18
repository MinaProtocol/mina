open Core
open Async

module State_worker = struct
  type t =
    {mutable state: int; reader: int Pipe.Reader.t; writer: int Pipe.Writer.t}

  type input = int [@@deriving bin_io]

  type state = int [@@deriving bin_io]

  let create input : t =
    let reader, writer = Pipe.create () in
    {state= input; reader; writer}

  let new_states {reader} = reader

  let run t =
    t.state <- 2 * t.state ;
    Pipe.write t.writer t.state
end

module Worker = Spawner.Parallel_worker.Make (State_worker)
module Master = Spawner.Master.Make (Worker) (Int)

let master_command =
  let open Command.Let_syntax in
  let%map {host; executable_path; log_dir} = Util.config_arguments in
  fun () ->
    let open Deferred.Let_syntax in
    let open Master in
    Parallel.init_master () ;
    let t = create () in
    let%bind log_dir = Util.create_dir log_dir in
    let config = {Spawner.Config.host; executable_path; log_dir}
    and process = 1 in
    let%bind () = add t 1 process ~config in
    let%bind () = Option.value_exn (run t process) in
    let reader = new_states t and expected_state = 2 in
    let%map actual_state = Util.read reader in
    assert (expected_state = actual_state)

let () = Util.run master_command
