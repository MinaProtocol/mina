open Core
open Async

(**
 * Test the basic functionality of the coda daemon and client through the CLI
 *)

let%test_module "Command line tests" =
  ( module struct
    (* executable location relative to src/default/lib/command_line_tests

       dune won't allow running it via "dune exec", because it's outside its
       workspace, so we invoke the executable directly

       the coda.exe executable must have been built before running the test
       here, else it will fail

     *)
    let coda_exe = "../../app/cli/src/coda.exe"

    let start_daemon config_dir port =
      Process.run ~prog:coda_exe
        ~args:
          [ "daemon"
          ; "-background"
          ; "-client-port"
          ; sprintf "%d" port
          ; "-config-directory"
          ; config_dir ]
        ()

    let stop_daemon port =
      Process.run () ~prog:coda_exe
        ~args:["client"; "stop-daemon"; "-daemon-port"; sprintf "%d" port]

    let start_client port =
      Process.run ~prog:coda_exe
        ~args:["client"; "status"; "-daemon-port"; sprintf "%d" port]
        ()

    let create_config_directory () =
      (* create empty config dir to avoid any issues with the default config dir *)
      Filename.temp_dir ~in_dir:"/tmp" "coda_spun_test" ""

    let _remove_config_directory config_dir =
      let%bind _ = Process.run_exn ~prog:"rm" ~args:["-rf"; config_dir] () in
      Deferred.unit

    let test_background_daemon () =
      let port = 1337 in
      let client_delay = 40. in
      let config_dir = create_config_directory () in
      Monitor.protect
        ~finally:(fun () ->
          Print.printf "log is at: %s\n" config_dir ;
          Deferred.unit (* remove_config_directory config_dir *) )
        (fun () ->
          let%bind err = start_daemon config_dir port in
          ignore (Or_error.ok_exn err) ;
          (* it takes awhile for the daemon to become available *)
          let%bind () = after (Time.Span.of_sec client_delay) in
          let%bind result = start_client port in
          let%map _ = stop_daemon port in
          result )

    let%test "The coda daemon works in background mode" =
      match Core.Sys.is_file coda_exe with
      | `Yes ->
          Async.Thread_safe.block_on_async_exn (fun () ->
              match%map test_background_daemon () with
              | Ok _ ->
                  true
              | Error e ->
                  printf "Error: %s" (Error.to_string_hum e) ;
                  false )
      | `No | `Unknown ->
          printf "Please build coda.exe in order to run this test\n%!" ;
          false
  end )
