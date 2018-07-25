open Core
open Async

module type Test = sig
  val command : Async.Command.t

  val name : string
end

let tests = [(module Different_pid : Test); (module Simple_worker : Test)]

let () =
  Random.self_init () ;
  let worker_argument =
    (Parallel.worker_command_name, Parallel.worker_command)
  in
  let test_arguments =
    worker_argument
    :: List.map tests ~f:(fun test ->
           let module Program = (val (test : (module Test))) in
           (Program.name, Program.command) )
  in
  Command.group test_arguments ~summary:"Task" |> Command.run ;
  never_returns (Scheduler.go ())
