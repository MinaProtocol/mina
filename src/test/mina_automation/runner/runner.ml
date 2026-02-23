open Async
open Core
open Mina_automation_fixture

let run (module F : Intf.Fixture) =
  let%bind test_case_after_setup =
    match%bind F.setup () with
    | Ok t ->
        return t
    | Error err ->
        failwithf "Setup failed with error: %s" (Error.to_string_hum err) ()
  in
  Monitor.protect
    ~finally:(fun () ->
      match%map F.teardown test_case_after_setup with
      | Ok () ->
          ()
      | Error err ->
          eprintf "Teardown failed with error: %s\n" (Error.to_string_hum err)
      )
    (fun () ->
      match%bind F.test_case test_case_after_setup with
      | Ok result ->
          return result
      | Error err ->
          let%map () = F.on_test_fail test_case_after_setup in
          Intf.Failed (Error.to_string_hum err) )

let run_blocking test_case () =
  match Async.Thread_safe.block_on_async_exn (fun () -> run test_case) with
  | Intf.Passed ->
      ()
  | Warning msg | Failed msg ->
      Alcotest.fail msg
