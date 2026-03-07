open Async
open Core

let logger = Logger.null ()

let async_with_temp_dir f =
  Async.Thread_safe.block_on_async_exn (fun () ->
      Mina_stdlib_unix.File_system.with_temp_dir
        (Filename.temp_dir_name ^/ "child-processes")
        ~f )

let name = "tester.sh"

let git_root_relative_path = "src/lib/child_processes/tester.sh"

let process_wait_timeout = Time.Span.of_sec 2.1

let test_can_launch_and_get_stdout () =
  async_with_temp_dir (fun conf_dir ->
      let open Deferred.Let_syntax in
      let%bind process =
        Child_processes.start_custom ~logger ~name ~git_root_relative_path
          ~conf_dir ~args:[ "exit" ] ~stdout:`Chunks ~stderr:`Chunks
          ~termination:`Raise_on_failure ()
        |> Deferred.map ~f:Or_error.ok_exn
      in
      let%bind () =
        Pipe_lib.Strict_pipe.Reader.iter (Child_processes.stdout process)
          ~f:(fun line ->
            Alcotest.(check string) "stdout line" "hello\n" line ;
            Deferred.unit )
      in
      (* Pipe will be closed before the ivar is filled, so we need to wait a
         bit. *)
      let%bind () = after process_wait_timeout in
      let res = Child_processes.termination_status process in
      let () =
        match res with
        | Some (Ok (Ok ())) ->
            ()
        | _ ->
            Alcotest.fail
              "Expected termination status to be Some (Ok (Ok ()))"
      in
      Deferred.unit )

let test_killing_works () =
  async_with_temp_dir (fun conf_dir ->
      let open Deferred.Let_syntax in
      let%bind process =
        Child_processes.start_custom ~logger ~name ~git_root_relative_path
          ~conf_dir ~args:[ "loop" ] ~stdout:`Lines ~stderr:`Lines
          ~termination:`Always_raise ()
        |> Deferred.map ~f:Or_error.ok_exn
      in
      let lock_exists () =
        Deferred.map
          (Async.Sys.file_exists (conf_dir ^/ name ^ ".lock"))
          ~f:(function `Yes -> true | _ -> false)
      in
      let assert_lock_exists () =
        Deferred.map (lock_exists ()) ~f:(fun exists -> assert exists)
      in
      let assert_lock_does_not_exist () =
        Deferred.map (lock_exists ()) ~f:(fun exists -> assert (not exists))
      in
      let%bind () = assert_lock_exists () in
      let output = ref [] in
      let rec go () =
        match%bind
          Pipe_lib.Strict_pipe.Reader.read (Child_processes.stdout process)
        with
        | `Eof ->
            failwith "pipe closed when process should've run forever"
        | `Ok line ->
            output := line :: !output ;
            if List.length !output = 10 then Deferred.unit else go ()
      in
      let%bind () = go () in
      Alcotest.(check (list string))
        "output lines"
        (List.init 10 ~f:(fun _ -> "hello"))
        !output ;
      let%bind () = after process_wait_timeout in
      assert (Option.is_none @@ Child_processes.termination_status process) ;
      let%bind kill_res = Child_processes.kill process in
      let%bind () = assert_lock_does_not_exist () in
      let exit_or_signal = Or_error.ok_exn kill_res in
      ( match exit_or_signal with
      | Error (`Signal s) ->
          Alcotest.(check string) "signal" "term" (Signal.to_string s)
      | _ ->
          Alcotest.fail "Expected Error (`Signal Signal.term)" ) ;
      assert (Option.is_some @@ Child_processes.termination_status process) ;
      Deferred.unit )

let test_spawn_two_processes () =
  async_with_temp_dir (fun conf_dir ->
      let open Deferred.Let_syntax in
      let mk_process () =
        Child_processes.start_custom ~logger ~name ~git_root_relative_path
          ~conf_dir ~args:[ "loop" ] ~stdout:`Chunks ~stderr:`Chunks
          ~termination:`Ignore ()
      in
      let%bind process1 =
        mk_process () |> Deferred.map ~f:Or_error.ok_exn
      in
      let%bind process2 =
        mk_process () |> Deferred.map ~f:Or_error.ok_exn
      in
      let%bind () = after process_wait_timeout in
      (* process1 should have been killed when process2 started *)
      ( match Child_processes.termination_status process1 with
      | Some (Ok (Error (`Signal s))) ->
          Alcotest.(check string) "signal" "term" (Signal.to_string s)
      | _ ->
          Alcotest.fail
            "Expected process1 termination_status to be Some (Ok (Error \
             (`Signal Signal.term)))" ) ;
      (* process2 should still be running *)
      assert (Option.is_none @@ Child_processes.termination_status process2) ;
      let%bind _ = Child_processes.kill process2 in
      Deferred.unit )

let test_lockfile_already_exists () =
  async_with_temp_dir (fun conf_dir ->
      let open Deferred.Let_syntax in
      let lock_path = conf_dir ^/ name ^ ".lock" in
      let%bind () = Async.Writer.save lock_path ~contents:"123" in
      let%bind process =
        Child_processes.start_custom ~logger ~name ~git_root_relative_path
          ~conf_dir ~args:[ "exit" ] ~stdout:`Chunks ~stderr:`Chunks
          ~termination:`Raise_on_failure ()
        |> Deferred.map ~f:Or_error.ok_exn
      in
      let%bind () =
        Pipe_lib.Strict_pipe.Reader.iter (Child_processes.stdout process)
          ~f:(fun line ->
            Alcotest.(check string) "stdout line" "hello\n" line ;
            Deferred.unit )
      in
      let%bind () = after process_wait_timeout in
      ( match Child_processes.termination_status process with
      | Some (Ok (Ok ())) ->
          ()
      | _ ->
          Alcotest.fail
            "Expected termination_status to be Some (Ok (Ok ()))" ) ;
      Deferred.unit )

let () =
  let open Alcotest in
  run "child_processes"
    [ ( "can_launch_and_get_stdout"
      , [ test_case "can launch and get stdout" `Quick
            test_can_launch_and_get_stdout
        ] )
    ; ( "killing_works"
      , [ test_case "killing works" `Quick test_killing_works ] )
    ; ( "spawn_two_processes"
      , [ test_case "if you spawn two processes it kills the earlier one"
            `Quick test_spawn_two_processes
        ] )
    ; ( "lockfile_already_exists"
      , [ test_case
            "if the lockfile already exists, then it would be cleaned" `Quick
            test_lockfile_already_exists
        ] )
    ]
