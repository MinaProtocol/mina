open Core
open Async

(**
 * Test the basic functionality of the coda daemon and client through the CLI
 *)

let%test_module "Command line tests" =
  ( module struct
    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    (* executable location relative to src/default/lib/command_line_tests

       dune won't allow running it via "dune exec", because it's outside its
       workspace, so we invoke the executable directly

       the coda.exe executable must have been built before running the test
       here, else it will fail

     *)
    let coda_exe = "../../app/cli/src/coda.exe"

    let _ = ()

    let runtime_genesis_ledger_exe =
      "../../app/runtime_genesis_ledger/runtime_genesis_ledger.exe"

    let generate_genesis_state dir =
      let all_accounts = Account_config.Fake_accounts.generate 5 in
      let _ =
        Out_channel.with_file (dir ^/ "accounts.json") ~f:(fun json_file ->
            Yojson.Safe.pretty_to_channel json_file
              (Account_config.to_yojson all_accounts) )
      in
      let%map _ =
        match%map
          Process.run ~prog:runtime_genesis_ledger_exe
            ~args:["-account-file"; dir ^/ "accounts.json"; "-genesis-dir"; dir]
            ()
        with
        | Ok s ->
            Core.printf !"Generated genesis ledger and base proof: %s\n" s
        | Error e ->
            Core.printf
              !"Error generating genesis ledger and base proof: %s\n"
              (Error.to_string_hum e)
      in
      Ok ()

    let start_daemon config_dir genesis_ledger_dir port =
      let%bind working_dir = Sys.getcwd () in
      Core.printf "Starting daemon inside %s\n" working_dir ;
      let%map _ =
        match%map
          Process.run ~prog:coda_exe
            ~args:
              [ "daemon"
              ; "-working-dir"
              ; working_dir
              ; "-background"
              ; "-client-port"
              ; sprintf "%d" port
              ; "-config-directory"
              ; config_dir
              ; "-genesis-ledger-dir"
              ; genesis_ledger_dir ]
            ()
        with
        | Ok s ->
            Core.printf !"Started daemon: %s\n" s
        | Error e ->
            Core.printf !"Error starting daemon: %s\n" (Error.to_string_hum e)
      in
      Ok ()

    let stop_daemon port =
      Process.run () ~prog:coda_exe
        ~args:["client"; "stop-daemon"; "-daemon-port"; sprintf "%d" port]

    let start_client port =
      Process.run ~prog:coda_exe
        ~args:["client"; "status"; "-daemon-port"; sprintf "%d" port]
        ()

    let create_config_directories () =
      (* create empty config dir to avoid any issues with the default config dir *)
      let conf = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
      let genesis = Filename.temp_dir ~in_dir:"/tmp" "coda_genesis_state" "" in
      (conf, genesis)

    let remove_config_directory config_dir genesis_dir =
      let%bind _ = Process.run_exn ~prog:"rm" ~args:["-rf"; config_dir] () in
      Process.run_exn ~prog:"rm" ~args:["-rf"; genesis_dir] ()
      |> Deferred.ignore_m

    let test_background_daemon () =
      let test_failed = ref false in
      let port = 1337 in
      let client_delay = 40. in
      let config_dir, genesis_ledger_dir = create_config_directories () in
      Monitor.protect
        ~finally:(fun () ->
          ( if !test_failed then
            let contents =
              Core.In_channel.(
                with_file (config_dir ^/ "coda.log") ~f:input_all)
            in
            Core.Printf.printf
              !"**** DAEMON CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
              contents ) ;
          remove_config_directory config_dir genesis_ledger_dir )
        (fun () ->
          match%map
            let open Deferred.Or_error.Let_syntax in
            let%bind _ = generate_genesis_state genesis_ledger_dir in
            let%bind _ = start_daemon config_dir genesis_ledger_dir port in
            (* it takes awhile for the daemon to become available *)
            let%bind () =
              Deferred.map
                (after @@ Time.Span.of_sec client_delay)
                ~f:Or_error.return
            in
            let%bind _ = start_client port in
            let%map _ = stop_daemon port in
            ()
          with
          | Ok () ->
              true
          | Error err ->
              test_failed := true ;
              Error.raise err )

    let%test "The coda daemon works in background mode" =
      match
        (Core.Sys.is_file coda_exe, Core.Sys.is_file runtime_genesis_ledger_exe)
      with
      | `Yes, `Yes ->
          Async.Thread_safe.block_on_async_exn test_background_daemon
      | _ ->
          printf
            !"Please build coda.exe and runtime_genesis_ledger.exe in order \
              to run this test\n\
              %!" ;
          false
  end )
