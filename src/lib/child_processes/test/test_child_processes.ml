open Async
open Core

let logger = Logger.null ()

let async_with_temp_dir f =
  Async.Thread_safe.block_on_async_exn (fun () ->
      File_system.with_temp_dir (Filename.temp_dir_name ^/ "child-processes") ~f )

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
            failwithf
              "Expected termination status to be Some (Ok (Ok ())), got %s"
              (Or_error.to_string_hum (Option.value_exn res))
      in
      Deferred.unit )

(* let%test_unit "killing works" = *)
(*   async_with_temp_dir (fun conf_dir -> *)
(*       let open Deferred.Let_syntax in *)
(*       let%bind process = *)
(*         start_custom ~logger ~name ~git_root_relative_path ~conf_dir *)
(*           ~args:[ "loop" ] ~stdout:`Lines ~stderr:`Lines *)
(*           ~termination:`Always_raise () *)
(*         |> Deferred.map ~f:Or_error.ok_exn *)
(*       in *)
(*       let lock_exists () = *)
(*         Deferred.map *)
(*           (Sys.file_exists (conf_dir ^/ name ^ ".lock")) *)
(*           ~f:(function `Yes -> true | _ -> false) *)
(*       in *)
(*       let assert_lock_exists () = *)
(*         Deferred.map (lock_exists ()) ~f:(fun exists -> assert exists) *)
(*       in *)
(*       let assert_lock_does_not_exist () = *)
(*         Deferred.map (lock_exists ()) ~f:(fun exists -> assert (not exists)) *)
(*       in *)
(*       let%bind () = assert_lock_exists () in *)
(*       let output = ref [] in *)
(*       let rec go () = *)
(*         match%bind Strict_pipe.Reader.read (stdout process) with *)
(*         | `Eof -> *)
(*             failwith "pipe closed when process should've run forever" *)
(*         | `Ok line -> *)
(*             output := line :: !output ; *)
(*             if List.length !output = 10 then Deferred.unit else go () *)
(*       in *)
(*       let%bind () = go () in *)
(*       [%test_eq: string list] !output (List.init 10 ~f:(fun _ -> "hello")) ; *)
(*       let%bind () = after process_wait_timeout in *)
(*       assert (Option.is_none @@ termination_status process) ; *)
(*       let%bind kill_res = kill process in *)
(*       let%bind () = assert_lock_does_not_exist () in *)
(*       let exit_or_signal = Or_error.ok_exn kill_res in *)
(*       [%test_eq: Unix.Exit_or_signal.t] exit_or_signal *)
(*         (Error (`Signal Signal.term)) ; *)
(*       assert (Option.is_some @@ termination_status process) ; *)
(*       Deferred.unit ) *)

(* let%test_unit "if you spawn two processes it kills the earlier one" = *)
(*   async_with_temp_dir (fun conf_dir -> *)
(*       let open Deferred.Let_syntax in *)
(*       let mk_process () = *)
(*         start_custom ~logger ~name ~git_root_relative_path ~conf_dir *)
(*           ~args:[ "loop" ] ~stdout:`Chunks ~stderr:`Chunks *)
(*           ~termination:`Ignore () *)
(*       in *)
(*       let%bind process1 = *)
(*         mk_process () |> Deferred.map ~f:Or_error.ok_exn *)
(*       in *)
(*       let%bind process2 = *)
(*         mk_process () |> Deferred.map ~f:Or_error.ok_exn *)
(*       in *)
(*       let%bind () = after process_wait_timeout in *)
(*       [%test_eq: Unix.Exit_or_signal.t Or_error.t option] *)
(*         (termination_status process1) *)
(*         (Some (Ok (Error (`Signal Core.Signal.term)))) ; *)
(*       [%test_eq: Unix.Exit_or_signal.t Or_error.t option] *)
(*         (termination_status process2) *)
(*         None ; *)
(*       let%bind _ = kill process2 in *)
(*       Deferred.unit ) *)

(* let%test_unit "if the lockfile already exists, then it would be cleaned" = *)
(*   async_with_temp_dir (fun conf_dir -> *)
(*       let open Deferred.Let_syntax in *)
(*       let lock_path = conf_dir ^/ name ^ ".lock" in *)
(*       let%bind () = Async.Writer.save lock_path ~contents:"123" in *)
(*       let%bind process = *)
(*         start_custom ~logger ~name ~git_root_relative_path ~conf_dir *)
(*           ~args:[ "exit" ] ~stdout:`Chunks ~stderr:`Chunks *)
(*           ~termination:`Raise_on_failure () *)
(*         |> Deferred.map ~f:Or_error.ok_exn *)
(*       in *)
(*       let%bind () = *)
(*         Strict_pipe.Reader.iter (stdout process) ~f:(fun line -> *)
(*             [%test_eq: string] "hello\n" line ; *)
(*             Deferred.unit ) *)
(*       in *)
(*       let%bind () = after process_wait_timeout in *)
(*       [%test_eq: Unix.Exit_or_signal.t Or_error.t option] (Some (Ok (Ok ()))) *)
(*         (termination_status process) ; *)
(*       Deferred.unit *)

let () =
  let open Alcotest in
  run "child_processes"
    [ ( "can_launch_and_get_stdout"
      , [ test_case "can launch and get stdout" `Quick
            test_can_launch_and_get_stdout
        ] )
      (* Uncomment the tests below to run them *)
      (* ; ( "killing works"
           , [ test_case "killing works" `Quick killing_works ] )
         ; ( "if you spawn two processes it kills the earlier one"
           , [ test_case "if you spawn two processes it kills the earlier one" `Quick
               if_you_spawn_two_processes_it_kills_the_earlier_one ] )
         ; ( "if the lockfile already exists, then it would be cleaned"
           , [ test_case "if the lockfile already exists, then it would be cleaned" `Quick
               if_the_lockfile_already_exists_then_it_would_be_cleaned ] ) *)
    ]
