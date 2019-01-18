open Core
open Async

(**
 * This module tests the basic funtionalities of coda through the cli
 *)

let%test_module "Command line tests" =
  ( module struct
    let kill p =
      Process.run_exn () ~prog:"kill" ~args:[Pid.to_string @@ Process.pid p]

    let test_background_daemon () =
      let open Deferred.Let_syntax in
      let port = 1337 in
      let%bind daemon_process =
        Process.create_exn ~prog:"dune"
          ~args:
            [ "exec"
            ; "coda"
            ; "daemon"
            ; "--"
            ; "-background"
            ; "-client-port"
            ; sprintf "%d" port ]
          ()
      in
      let%bind result =
        Process.run ~prog:"dune"
          ~args:
            [ "exec"
            ; "coda"
            ; "client"
            ; "status"
            ; "--"
            ; "-daemon-port"
            ; sprintf "%d" port ]
          ()
      in
      let%map _ : string = kill daemon_process in
      result

    let%test "The coda daemon performs work in the background" =
      Async.Thread_safe.block_on_async_exn (fun () ->
          test_background_daemon () |> Deferred.map ~f:Result.is_ok )
  end )
