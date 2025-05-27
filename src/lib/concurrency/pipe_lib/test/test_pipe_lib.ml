open Async
open Core_kernel
open Pipe_lib

let test_reader_hang () =
  let swappable =
    Strict_pipe.Swappable.create ~name:"swappable"
      (Buffered (`Capacity 50, `Overflow (Drop_head (const ()))))
  in
  let%bind _hanging_reader =
    Strict_pipe.Swappable.swap_reader ~reader_name:"hanging reader" swappable
  in
  let () = Strict_pipe.Swappable.write swappable () in
  let%bind good_reader =
    Strict_pipe.Swappable.swap_reader ~reader_name:"good reader" swappable
  in
  let timeouted = ref true in
  after (Time.Span.of_sec 1.5)
  >>| (fun () ->
        if !timeouted then failwith "Swappable strict pipe hangs, timeout!" )
  |> Deferred.don't_wait_for ;
  let () = Strict_pipe.Swappable.write swappable () in
  match%map Strict_pipe.Reader.read good_reader with
  | `Ok () ->
      timeouted := false
  | `Eof ->
      failwith "written () to pipe got `Eof"

let () =
  Async.Thread_safe.block_on_async_exn (fun () ->
      let open Alcotest_async in
      run "Pipe_lib"
        [ ( "Strict_pipe.Swappable"
          , [ Alcotest_async.test_case "reader hangs" `Quick test_reader_hang ]
          )
        ] )
