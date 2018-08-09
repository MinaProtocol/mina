open Core
open Async
open Spawner

module State_worker = struct
  type t =
    {mutable state: int; reader: int Pipe.Reader.t; writer: int Pipe.Writer.t}

  type input = int [@@deriving bin_io]

  type state = int [@@deriving bin_io]

  let create input =
    let reader, writer = Pipe.create () in
    return @@ {state= input; reader; writer}

  let new_states {reader} = reader

  let run t =
    printf "Hello World from State worker" ;
    t.state <- 2 * t.state ;
    Pipe.write t.writer t.state
end

module Worker = Parallel_worker.Make (State_worker)
module Master = Master.Make (Worker (Int)) (Int)

let master_command =
  let open Command.Let_syntax in
  let%map {host; executable_path} = Command_util.config_arguments in
  fun () ->
    let open Deferred.Let_syntax in
    let open Master in
    let t = create () in
    let id = 1 in
    let config = {Config.id; host; executable_path} and input = 1 in
    let%bind () = add t id input ~config in
    let%bind () = Option.value_exn (run t input) in
    let reader = new_states t and expected_state = 2 in
    let%map _, actual_state = Linear_pipe.read_exn reader in
    assert (expected_state = actual_state)

let name = "simple-worker"

let command =
  Command.async master_command
    ~summary:"Tests that a worker can send updates to master"
