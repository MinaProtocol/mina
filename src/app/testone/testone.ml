open Core
open Async

let get_directory filename = Core.Filename.dirname filename

let compilation_dir = "_build" ^/ "default"

let inline_test_runner_arg = "inline-test-runner"

let only_test_arg = "-only-test"

let dune = "dune"

let wait process =
  Process.wait process
  >>| Result.map_error ~f:(function
        | `Signal signal ->
            Error.createf
              !"Process %{sexp:Process.t} interrupted by signal: %s"
              process
            @@ Signal.to_string signal
        | `Exit_non_zero i ->
            Error.createf
              !"Process %{sexp:Process.t} died with exit error %i"
              process i )

let write ?(build_dir = ".") ~loc filename =
  let dirpath = Filename.dirname filename in
  let library_name = Filename.basename dirpath in
  let test_runner_prog =
    dirpath ^/ Core.sprintf ".%s.inline-tests" library_name ^/ "run.exe"
  in
  let testcase =
    Option.value_map loc ~default:filename ~f:(fun loc ->
        sprintf !"%s:%i" filename loc )
  in
  let%bind compile_process =
    Process.create_exn ~prog:dune
      ~args:["build"; build_dir ^/ test_runner_prog]
      ()
  in
  File_system.dup_stdout compile_process ;
  File_system.dup_stderr compile_process ;
  let%bind () = wait compile_process >>| Or_error.ok_exn in
  let%bind runtime_process =
    Process.create_exn
      ~prog:(build_dir ^/ compilation_dir ^/ test_runner_prog)
      ~args:[inline_test_runner_arg; library_name; only_test_arg; testcase]
      ()
  in
  File_system.dup_stdout runtime_process ;
  File_system.dup_stderr runtime_process ;
  wait runtime_process >>| Or_error.ok_exn

let command =
  let open Command.Let_syntax in
  let%map_open filename = anon ("filename" %: string)
  and loc = anon @@ maybe @@ ("line-number" %: int) in
  fun () -> write ~loc filename

let () =
  Command.run @@ Command.async ~summary:"Run a single test on dune" command
