open Core
open Async

module type Test = sig
  val command : Async.Command.t

  val name : string
end

let tests = [(module Different_pid : Test); (module Simple_worker : Test)]

let run_all_tests () =
  Deferred.List.iter tests ~f:(fun (module T : Test) ->
      let%bind process =
        Process.create_exn ~prog:Sys.executable_name ~args:[T.name] ()
      in
      File_system.dup_stdout process ;
      File_system.dup_stderr process ;
      Process.wait process |> Deferred.ignore )

let () =
  Random.self_init () ;
  let worker_argument = (Parallel.worker_command_name, Parallel.worker_command)
  and all_test_argument =
    ( "all-tests"
    , Command.async ~summary:"Runs all integration tests"
        (Command.Param.return run_all_tests) )
  in
  let test_arguments =
    worker_argument :: all_test_argument
    :: List.map tests ~f:(fun (module T : Test) -> (T.name, T.command))
  in
  Command.group test_arguments ~summary:"Task" |> Command.run

let () = never_returns (Scheduler.go ())
