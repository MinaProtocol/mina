open Core
open Async

(**
 * Test the basic functionality of the mina daemon and client through the CLI
 *)

let%test_module "Command line tests" =
  ( module struct
    let () =
      Backtrace.elide := false ;
      Async.Scheduler.set_record_backtraces true

    (* executable location relative to src/default/lib/command_line_tests

       dune won't allow running it via "dune exec", because it's outside its
       workspace, so we invoke the executable directly

       the mina.exe executable must have been built before running the test
       here, else it will fail
    *)
    let coda_exe = "../../app/cli/src/mina.exe"

    let create_daemon_process config_dir genesis_ledger_dir libp2p_keypair_path
        port =
      let%bind working_dir = Sys.getcwd () in
      Core.printf "Starting daemon inside %s\n" working_dir ;
      Process.create ~prog:coda_exe
        ~args:
          [ "daemon"
          ; "-seed"
          ; "-working-dir"
          ; working_dir
          ; "-client-port"
          ; sprintf "%d" port
          ; "-config-directory"
          ; config_dir
          ; "-genesis-ledger-dir"
          ; genesis_ledger_dir
          ; "-current-protocol-version"
          ; "0.0.0"
          ; "-external-ip"
          ; "0.0.0.0"
          ; "-libp2p-keypair"
          ; libp2p_keypair_path
          ]
        ()

    let start_daemon config_dir genesis_ledger_dir libp2p_keypair_path port =
      let%bind working_dir = Sys.getcwd () in
      Core.printf "Starting daemon inside %s\n" working_dir ;
      let%map _ =
        match%map
          Process.run ~prog:coda_exe
            ~args:
              [ "daemon"
              ; "-seed"
              ; "-working-dir"
              ; working_dir
              ; "-background"
              ; "-client-port"
              ; sprintf "%d" port
              ; "-config-directory"
              ; config_dir
              ; "-genesis-ledger-dir"
              ; genesis_ledger_dir
              ; "-current-protocol-version"
              ; "0.0.0"
              ; "-external-ip"
              ; "0.0.0.0"
              ; "-libp2p-keypair"
              ; libp2p_keypair_path
              ]
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
        ~args:[ "client"; "stop-daemon"; "-daemon-port"; sprintf "%d" port ]

    let start_client port =
      Process.run ~prog:coda_exe
        ~args:[ "client"; "status"; "-daemon-port"; sprintf "%d" port ]
        ()

    let libp2p_keypath dir = String.concat [ dir; "/privkey" ]

    let create_config_files_and_dirs () =
      (* create empty config dir to avoid any issues with the default config dir *)
      let conf = Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" "" in
      let genesis = Filename.temp_dir ~in_dir:"/tmp" "coda_genesis_state" "" in
      let libp2p_keypair_dir =
        Filename.temp_dir ~in_dir:"/tmp" "mina_test_libp2p_keypair" ""
      in
      let libp2p_keypair_path = libp2p_keypath libp2p_keypair_dir in
      let%map () =
        Init.Client.generate_libp2p_keypair_do libp2p_keypair_path ()
      in
      (conf, genesis, libp2p_keypair_dir)

    let remove_config_dirs dirs =
      Deferred.List.iter dirs ~f:(fun dir ->
          Deferred.ignore_m
          @@ Process.run_exn ~prog:"rm" ~args:[ "-rf"; dir ] () )

    let test_background_daemon () =
      let test_failed = ref false in
      let port = 1337 in
      let client_delay = 40. in
      let retry_delay = 30. in
      let retry_attempts = 30 in
      let%bind config_dir, genesis_ledger_dir, libp2p_keypair_dir =
        create_config_files_and_dirs ()
      in
      Monitor.protect
        ~finally:(fun () ->
          ( if !test_failed then
            let contents =
              Core.In_channel.(
                with_file (config_dir ^/ "mina.log") ~f:input_all)
            in
            Core.Printf.printf
              !"**** DAEMON CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
              contents ) ;
          remove_config_dirs
            [ config_dir; genesis_ledger_dir; libp2p_keypair_dir ] )
        (fun () ->
          match%map
            let open Deferred.Or_error.Let_syntax in
            let%bind _ =
              start_daemon config_dir genesis_ledger_dir
                (libp2p_keypath libp2p_keypair_dir)
                port
            in
            (* It takes a while for the daemon to become available. *)
            let%bind () =
              Deferred.map
                (after @@ Time.Span.of_sec client_delay)
                ~f:Or_error.return
            in
            let%bind _ =
              let rec go retries_remaining =
                let open Deferred.Let_syntax in
                match%bind start_client port with
                | Error _ when retries_remaining > 0 ->
                    Core.Printf.printf
                      "Daemon not responding.. retrying (%i/%i)\n"
                      (retry_attempts - retries_remaining)
                      retry_attempts ;
                    let%bind () = after @@ Time.Span.of_sec retry_delay in
                    go (retries_remaining - 1)
                | ret ->
                    return ret
              in
              go retry_attempts
            in
            let%map _ = stop_daemon port in
            ()
          with
          | Ok () ->
              true
          | Error err ->
              test_failed := true ;
              Error.raise err )

    let test_daemon_recover () =
      let test_failed = ref false in
      let port = 1337 in
      let client_delay = 40. in
      let retry_delay = 30. in
      let retry_attempts = 5 in
      let%bind config_dir, genesis_ledger_dir, libp2p_keypair_dir =
        create_config_files_and_dirs ()
      in
      Monitor.protect
        ~finally:(fun () ->
          ( if !test_failed then
            let contents =
              Core.In_channel.(
                with_file (config_dir ^/ "mina.log") ~f:input_all)
            in
            Core.Printf.printf
              !"**** DAEMON CRASHED (OUTPUT BELOW) ****\n%s\n************\n%!"
              contents ) ;
          remove_config_dirs
            [ config_dir; genesis_ledger_dir; libp2p_keypair_dir ] )
        (fun () ->
          match%map
            let open Deferred.Or_error.Let_syntax in
            let libp2p_keypair_path = libp2p_keypath libp2p_keypair_dir in
            let%bind p =
              create_daemon_process config_dir genesis_ledger_dir
                libp2p_keypair_path port
            in
            let%bind () =
              Deferred.map
                (after @@ Time.Span.of_sec client_delay)
                ~f:Or_error.return
            in
            let rec call_client retries_remaining =
              let open Deferred.Let_syntax in
              match%bind start_client port with
              | Error _ when retries_remaining > 0 ->
                  Core.Printf.printf
                    "Daemon not responding.. retrying (%i/%i)\n"
                    (retry_attempts - retries_remaining)
                    retry_attempts ;
                  let%bind () = after @@ Time.Span.of_sec retry_delay in
                  call_client (retries_remaining - 1)
              | ret ->
                  return ret
            in
            let%bind _ = call_client retry_attempts in
            Process.send_signal p Core.Signal.kill ;
            let%bind (_ : Unix.Exit_or_signal.t) =
              Deferred.map (Process.wait p) ~f:Or_error.return
            in
            let%bind _ =
              start_daemon config_dir genesis_ledger_dir libp2p_keypair_path
                port
            in
            let%bind () =
              Deferred.map
                (after @@ Time.Span.of_sec client_delay)
                ~f:Or_error.return
            in
            let%bind _ = call_client retry_attempts in
            let%map _ = stop_daemon port in
            ()
          with
          | Ok () ->
              true
          | Error err ->
              test_failed := true ;
              Error.raise err )

    let%test "The mina daemon works in background mode" =
      match Core.Sys.is_file coda_exe with
      | `Yes ->
          Async.Thread_safe.block_on_async_exn test_background_daemon
      | _ ->
          printf !"Please build mina.exe in order to run this test\n%!" ;
          false

    let%test "The mina daemon recovers from crashes" =
      match Core.Sys.is_file coda_exe with
      | `Yes ->
          Async.Thread_safe.block_on_async_exn test_daemon_recover
      | _ ->
          printf !"please build mina.exe in order to run this test\n%!" ;
          false
  end )
