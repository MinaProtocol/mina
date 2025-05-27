open Async
open Core_kernel
open Pipe_lib

let test_reader_hang () =
  let replacable =
    Strict_pipe.Replaceable.create ~name:"replacable"
      (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))
  in
  let%bind _hanging_reader =
    Strict_pipe.Replaceable.request_reader ~reader_name:"hanging reader"
      replacable
  in
  let () = Strict_pipe.Replaceable.write replacable () in
  let%bind good_reader =
    Strict_pipe.Replaceable.request_reader ~reader_name:"good reader" replacable
  in
  let timeouted = ref true in
  after (Time.Span.of_sec 1.5)
  >>| (fun () ->
        if !timeouted then failwith "Replaceable strict pipe hangs, timeout!" )
  |> Deferred.don't_wait_for ;
  let () = Strict_pipe.Replaceable.write replacable () in
  match%map Strict_pipe.Reader.read good_reader with
  | `Ok () ->
      timeouted := false
  | `Eof ->
      failwith "written () to pipe got `Eof"

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Strict_pipe.Replaceable"
          , [ Alcotest_async.test_case "reader hangs" `Quick test_reader_hang ]
          )
        ] )
