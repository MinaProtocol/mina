open Async
open Core
open Mina_automation_fixture

let run (module F : Intf.Fixture) =
  let open Deferred.Let_syntax in
  let%bind test_case_after_setup =
    match%bind.Deferred F.setup () with
    | Ok t ->
        return t
    | Error err ->
        failwithf "Setup failed with error: %s" (Error.to_string_hum err) ()
  in
  Monitor.protect
    ~finally:(fun () ->
      match%bind F.teardown test_case_after_setup with
      | Ok () ->
          Deferred.unit
      | Error err ->
          eprintf "Teardown failed with error: %s\n" (Error.to_string_hum err) ;
          Deferred.unit )
    (fun () ->
      match%bind.Deferred F.test_case test_case_after_setup with
      | Ok result ->
          return result
      | Error err ->
          let%map _ = F.on_test_fail test_case_after_setup in
          Intf.Failed (Error.to_string_hum err) )

let run_blocking test_case () =
  let (_ : Intf.test_result) =
    Async.Thread_safe.block_on_async_exn (fun () -> run test_case)
  in
  ()
